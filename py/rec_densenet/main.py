import os
import torch
from torch import nn, optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader
from tqdm import tqdm
import logging
from datetime import datetime
import time

# 设置路径（保持原样）
train_dir = "G:/database/shipsEar/shipsEar_Enhanced/train_cb_pic_rgb"
val_dir = "G:/database/shipsEar/shipsEar_Enhanced/val_cb_pic_rgb"
batch_size = 64
num_epochs = 32
learning_rate = 0.001
num_classes = 5
model_save_path = "densenet_model.pth"  # 修改模型保存名称

# 获取当前时间戳
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

# 设置日志记录
log_file = f"densenet_training_log_{current_time}.txt"
logging.basicConfig(filename=log_file, level=logging.INFO,
                    format='%(asctime)s - %(message)s')
logging.info("DenseNet Training started...")

# 数据预处理（保持原样）
data_transforms = transforms.Compose([
    transforms.Resize((98, 98)),
    transforms.ToTensor(),
    transforms.Lambda(lambda x: (x - x.mean(dim=(1, 2), keepdim=True)) / (x.std(dim=(1, 2), keepdim=True) + 1e-8))
])

# 加载数据集（保持原样）
train_dataset = datasets.ImageFolder(train_dir, transform=data_transforms)
val_dataset = datasets.ImageFolder(val_dir, transform=data_transforms)

train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, pin_memory=True)
val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, pin_memory=True)

# 定义DenseNet模型（使用densenet121）
from torchvision.models import densenet121, DenseNet121_Weights

# 加载预训练权重
model = densenet121(weights=DenseNet121_Weights.DEFAULT)

# 修改分类层（DenseNet的分类器名为classifier）
num_ftrs = model.classifier.in_features
model.classifier = nn.Linear(num_ftrs, num_classes)

device = torch.device("cuda")
model = model.to(device)

# 加载已有模型（如果存在）
if os.path.exists(model_save_path):
    model.load_state_dict(torch.load(model_save_path, weights_only=True))
    logging.info(f"DenseNet model loaded from {model_save_path}")

# 定义损失函数和优化器（保持原样）
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

# 训练时长统计（保持原样）
start_time = time.time()

# 训练循环（保持原样）
for epoch in range(num_epochs):
    model.train()
    running_loss = 0.0

    # 训练阶段
    train_progress = tqdm(train_loader, desc=f"Epoch {epoch + 1}/{num_epochs} Training", unit="batch")
    for inputs, labels in train_progress:
        inputs, labels = inputs.to(device), labels.to(device)

        # 前向传播
        outputs = model(inputs)
        loss = criterion(outputs, labels)

        # 反向传播
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        running_loss += loss.item()

    # 记录训练损失
    avg_loss = running_loss / len(train_loader)
    logging.info(f"Epoch {epoch + 1}/{num_epochs}, Training Loss: {avg_loss:.4f}")

    # 验证阶段
    model.eval()
    correct = 0
    total = 0
    val_progress = tqdm(val_loader, desc=f"Epoch {epoch + 1}/{num_epochs} Validation", unit="batch")
    with torch.no_grad():
        for inputs, labels in val_progress:
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            _, preds = torch.max(outputs, 1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)

    # 记录验证准确率
    val_acc = correct / total
    logging.info(f"Epoch {epoch + 1}/{num_epochs}, Validation Accuracy: {val_acc:.2%}")

# 保存模型
torch.save(model.state_dict(), model_save_path)
logging.info(f"DenseNet model saved to {model_save_path}")

# 计算总训练时长
end_time = time.time()
elapsed = end_time - start_time
logging.info(f"Training completed in {elapsed // 60:.0f}m {elapsed % 60:.0f}s")