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
train_dir = "G:/database/MergedDataset_single_env/Transition/train"
val_dir   = "G:/database/MergedDataset_single_env/Transition/val"
test_dir  = "G:/database/MergedDataset_single_env/Transition/test"

batch_size    = 128
num_epochs    = 32
learning_rate = 1e-3
num_classes   = 5
best_model_save_path = "best_model_resnet50.pth"

# 最小提升阈值
min_delta = 0.001  # 最小提升阈值

# ─── 2. 日志配置 ───
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
log_file = f"training_log_{current_time}.txt"

# 配置日志
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 创建文件处理器，指定UTF-8编码
file_handler = logging.FileHandler(log_file, encoding='utf-8')
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(message)s'))
logger.addHandler(file_handler)

# 写入训练参数信息
logging.info("="*50)
logging.info("训练参数:")
logging.info(f"- 批次大小: {batch_size}")
logging.info(f"- 学习率: {learning_rate}")
logging.info(f"- 类别数: {num_classes}")
logging.info(f"- 最小提升阈值: {min_delta}")
logging.info("="*50)
logging.info("训练开始...")

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

# 如果已有最佳模型，先加载权重
if os.path.exists(best_model_save_path):
    model.load_state_dict(torch.load(best_model_save_path, map_location=device, weights_only=True))
    logging.info(f"Loaded existing best model from {best_model_save_path}")

# ─── 6. 损失与优化器 ───
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)
# 学习率调度器
scheduler = optim.lr_scheduler.ReduceLROnPlateau(
    optimizer, mode='max', factor=0.1, patience=3
)

# ─── 7. 训练与验证 ───
start_time = time.time()
best_val_acc = 0.0
current_lr = learning_rate

for epoch in range(num_epochs):
    # ---- 训练 ----
    model.train()
    running_loss = 0.0
    train_pbar = tqdm(train_loader, desc=f"Epoch {epoch+1}/{num_epochs} Train", leave=True)
    for inputs, labels in train_pbar:
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss    = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        train_pbar.set_postfix({'loss': f'{loss.item():.4f}'})
    avg_loss = running_loss / len(train_loader)
    logging.info(f"Epoch {epoch+1}, Train Loss: {avg_loss:.4f}")

    # ---- 验证 ----
    model.eval()
    correct = total = 0
    val_pbar = tqdm(val_loader, desc=f"Epoch {epoch+1}/{num_epochs} Val", leave=True)
    with torch.no_grad():
        for inputs, labels in val_pbar:
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            preds   = outputs.argmax(dim=1)
            correct += (preds == labels).sum().item()
            total   += labels.size(0)
            val_pbar.set_postfix({'acc': f'{correct/total:.4f}'})
    val_acc = correct / total
    logging.info(f"Epoch {epoch+1}, Val Accuracy: {val_acc:.4f}")
    
    # 更新学习率
    old_lr = current_lr
    scheduler.step(val_acc)
    current_lr = optimizer.param_groups[0]['lr']
    
    # 如果学习率发生变化，记录日志
    if current_lr != old_lr:
        logging.info(f"学习率从 {old_lr:.6f} 降低到 {current_lr:.6f}")
        print(f"\n学习率从 {old_lr:.6f} 降低到 {current_lr:.6f}\n")
    
    # 保存最佳模型
    if val_acc > best_val_acc + min_delta:
        best_val_acc = val_acc
        torch.save(model.state_dict(), best_model_save_path)
        logging.info(f"New best model saved with val accuracy: {best_val_acc:.4f}")
    else:
        logging.info(f"No improvement in validation accuracy")

# ─── 8. 加载最佳模型进行测试 ───
model.load_state_dict(torch.load(best_model_save_path))
logging.info("加载最佳模型进行测试")

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
logging.info("="*50)
logging.info("测试集评估结果:")
logging.info(f"测试集准确率: {test_acc:.4f}")

# ---- 可选：打印分类报告和混淆矩阵 ----
print(classification_report(all_labels, all_preds, digits=4))
cm = confusion_matrix(all_labels, all_preds)
print("Confusion Matrix:\n", cm)

# 将分类报告和混淆矩阵写入日志
logging.info("\n分类报告:")
logging.info(classification_report(all_labels, all_preds, digits=4))
logging.info("\n混淆矩阵:")
logging.info(str(cm))

end_time = time.time()
elapsed = end_time - start_time
logging.info(f"\n总训练时间: {elapsed//60:.0f} 分钟 {elapsed%60:.0f} 秒")
logging.info("="*50)