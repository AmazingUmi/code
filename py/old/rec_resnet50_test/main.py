import os
import torch
from torch import nn, optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from torchvision.models import resnet50, ResNet50_Weights
from tqdm import tqdm
from datetime import datetime
import logging
import time
from sklearn.metrics import classification_report, confusion_matrix

# ─── 1. 数据路径 ───
train_dir = "G:/database/MergedDataset_ByCategory/train"
val_dir   = "G:/database/MergedDataset_ByCategory/val"
test_dir  = "G:/database/MergedDataset_ByCategory/test"

batch_size    = 256
num_epochs    = 32
learning_rate = 1e-3
num_classes   = 5
model_save_path = "model_resnet50.pth"

# ─── 2. 日志配置 ───
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
log_file = f"training_log_{current_time}.txt"
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)
logging.info("Training started...")

# ─── 3. 数据预处理 ───
data_transforms = transforms.Compose([
    transforms.Resize((98, 98)),
    transforms.ToTensor(),
    transforms.Lambda(lambda x: (x - x.mean(dim=(1,2), keepdim=True)) /
                              (x.std(dim=(1,2), keepdim=True) + 1e-8))
])

# ─── 4. 加载数据集 ───
train_dataset = datasets.ImageFolder(train_dir, transform=data_transforms)
val_dataset   = datasets.ImageFolder(val_dir,   transform=data_transforms)
test_dataset  = datasets.ImageFolder(test_dir,  transform=data_transforms)

train_loader = DataLoader(train_dataset, batch_size=batch_size,
                          shuffle=True,  pin_memory=True)
val_loader   = DataLoader(val_dataset,   batch_size=batch_size,
                          shuffle=False, pin_memory=True)
test_loader  = DataLoader(test_dataset,  batch_size=batch_size,
                          shuffle=False, pin_memory=True)

# ─── 5. 模型定义 ───
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = resnet50(weights=ResNet50_Weights.DEFAULT)
# 替换最后的全连接层
model.fc = nn.Linear(model.fc.in_features, num_classes)
model = model.to(device)

# 如果已有模型，先加载权重
if os.path.exists(model_save_path):
    model.load_state_dict(torch.load(model_save_path, map_location=device))
    logging.info(f"Loaded existing model from {model_save_path}")

# ─── 6. 损失与优化器 ───
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

# ─── 7. 训练与验证 ───
start_time = time.time()
for epoch in range(num_epochs):
    # ---- 训练 ----
    model.train()
    running_loss = 0.0
    for inputs, labels in tqdm(train_loader,
                               desc=f"Epoch {epoch+1}/{num_epochs} Train",
                               leave=False):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss    = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
    avg_loss = running_loss / len(train_loader)
    logging.info(f"Epoch {epoch+1}, Train Loss: {avg_loss:.4f}")

    # ---- 验证 ----
    model.eval()
    correct = total = 0
    with torch.no_grad():
        for inputs, labels in tqdm(val_loader,
                                   desc=f"Epoch {epoch+1}/{num_epochs} Val",
                                   leave=False):
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            preds   = outputs.argmax(dim=1)
            correct += (preds == labels).sum().item()
            total   += labels.size(0)
    val_acc = correct / total
    logging.info(f"Epoch {epoch+1}, Val Accuracy: {val_acc:.4f}")

# ─── 8. 保存模型 ───
torch.save(model.state_dict(), model_save_path)
logging.info(f"Model saved to {model_save_path}")

# ─── 9. 测试集评估 ───
model.eval()
correct = total = 0
all_preds = []
all_labels = []
with torch.no_grad():
    for inputs, labels in tqdm(test_loader, desc="Test", leave=False):
        inputs, labels = inputs.to(device), labels.to(device)
        outputs = model(inputs)
        preds   = outputs.argmax(dim=1)
        correct += (preds == labels).sum().item()
        total   += labels.size(0)
        all_preds.extend(preds.cpu().tolist())
        all_labels.extend(labels.cpu().tolist())

test_acc = correct / total
print(f"Test Accuracy: {test_acc:.4f}")
logging.info(f"Test Accuracy: {test_acc:.4f}")

# ---- 可选：打印分类报告和混淆矩阵 ----
print(classification_report(all_labels, all_preds, digits=4))
cm = confusion_matrix(all_labels, all_preds)
print("Confusion Matrix:\n", cm)

end_time = time.time()
elapsed = end_time - start_time
logging.info(f"Total time: {elapsed//60:.0f} min {elapsed%60:.0f} sec")
