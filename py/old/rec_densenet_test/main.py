import os
import random
import logging
import time
from datetime import datetime

import torch
from torch import nn, optim
from torch.utils.data import DataLoader, Subset
from torchvision import datasets, transforms
from torchvision.models import densenet121, DenseNet121_Weights
from tqdm import tqdm
from sklearn.metrics import classification_report, confusion_matrix

# ─── 1. 路径 & 参数配置 ─────────────────────────────────────────
train_dir         = "G:/database/MergedDataset_ByCategory/train"
val_dir           = "G:/database/MergedDataset_ByCategory/val"
test_dir          = "G:/database/MergedDataset_ByCategory/test"
subset_percentage = 0.1         # 从每个子集抽取 20% 样本
random_seed       = 42
batch_size        = 64
num_epochs        = 32
learning_rate     = 1e-3
num_classes       = 5
model_save_path   = "model.pth"

# ─── 2. 日志设置 ────────────────────────────────────────────────
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
log_file     = f"training_log_{current_time}.txt"
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logging.info("=== Training started ===")

# ─── 3. 数据预处理 ──────────────────────────────────────────────
data_transforms = transforms.Compose([
    transforms.Resize((98, 98)),
    transforms.ToTensor(),
    transforms.Lambda(
        lambda x: (x - x.mean(dim=(1, 2), keepdim=True)) /
                  (x.std(dim=(1, 2), keepdim=True) + 1e-8)
    )
])

# ─── 4. 加载完整数据集 ───────────────────────────────────────────
full_train_dataset = datasets.ImageFolder(train_dir, transform=data_transforms)
full_val_dataset   = datasets.ImageFolder(val_dir,   transform=data_transforms)
full_test_dataset  = datasets.ImageFolder(test_dir,  transform=data_transforms)

# ─── 5. 按比例抽样子集 ───────────────────────────────────────────
random.seed(random_seed)

num_train = int(len(full_train_dataset) * subset_percentage)
num_val   = int(len(full_val_dataset)   * subset_percentage)
num_test  = int(len(full_test_dataset)  * subset_percentage)

train_indices = random.sample(range(len(full_train_dataset)), num_train)
val_indices   = random.sample(range(len(full_val_dataset)),   num_val)
test_indices  = random.sample(range(len(full_test_dataset)),  num_test)

train_dataset = Subset(full_train_dataset, train_indices)
val_dataset   = Subset(full_val_dataset,   val_indices)
test_dataset  = Subset(full_test_dataset,  test_indices)

# ─── 6. DataLoader ──────────────────────────────────────────────
train_loader = DataLoader(train_dataset, batch_size=batch_size,
                          shuffle=True,  pin_memory=True)
val_loader   = DataLoader(val_dataset,   batch_size=batch_size,
                          shuffle=False, pin_memory=True)
test_loader  = DataLoader(test_dataset,  batch_size=batch_size,
                          shuffle=False, pin_memory=True)

# ─── 7. 模型 & 设备 ──────────────────────────────────────────────
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model  = densenet121(weights=DenseNet121_Weights.DEFAULT)
model.classifier = nn.Linear(model.classifier.in_features, num_classes)
model = model.to(device)

# 如果已有预训练权重，先加载
if os.path.exists(model_save_path):
    model.load_state_dict(torch.load(model_save_path, map_location=device))
    logging.info(f"Loaded existing model from {model_save_path}")

# ─── 8. 损失函数 & 优化器 ───────────────────────────────────────
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

# ─── 9. 训练 + 验证 循环 ────────────────────────────────────────
start_time = time.time()
for epoch in range(1, num_epochs + 1):
    # ---- 训练 ----
    model.train()
    running_loss = 0.0
    for inputs, labels in tqdm(train_loader,
                               desc=f"Epoch {epoch}/{num_epochs} - Train",
                               leave=False):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss    = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
    avg_loss = running_loss / len(train_loader)
    logging.info(f"Epoch {epoch} - Train Loss: {avg_loss:.4f}")

    # ---- 验证 ----
    model.eval()
    correct = total = 0
    with torch.no_grad():
        for inputs, labels in tqdm(val_loader,
                                   desc=f"Epoch {epoch}/{num_epochs} - Val",
                                   leave=False):
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            preds   = outputs.argmax(dim=1)
            correct += (preds == labels).sum().item()
            total   += labels.size(0)
    val_acc = correct / total
    logging.info(f"Epoch {epoch} - Val Accuracy: {val_acc:.4f}")

# ─── 10. 保存模型 ───────────────────────────────────────────────
torch.save(model.state_dict(), model_save_path)
logging.info(f"Model saved to {model_save_path}")

# ─── 11. 测试集评估 ─────────────────────────────────────────────
model.eval()
correct = total = 0
all_preds  = []
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

# ---- 打印分类报告和混淆矩阵 ----
print("\nClassification Report:")
print(classification_report(all_labels, all_preds, digits=4))
print("Confusion Matrix:")
print(confusion_matrix(all_labels, all_preds))

end_time = time.time()
elapsed = end_time - start_time
logging.info(f"Total elapsed time: {elapsed//60:.0f} min {elapsed%60:.0f} sec")
