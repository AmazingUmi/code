import os
import torch
from torch import nn, optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader
from tqdm import tqdm
import logging
from datetime import datetime
import time  # 导入 time 模块

# 设置路径
train_dir = "D:/database/shipsEar/shipsEar_reclassified/train_origin_pic/"  # 训练集的路径
val_dir = "D:/database/shipsEar/shipsEar_reclassified/val_origin_pic/"  # 验证集的路径
batch_size = 64
num_epochs = 16
learning_rate = 0.001
num_classes = 5  # 修改为你的类别数量
model_save_path = "model.pth"

# 获取当前时间戳，格式为：年-月-日_时-分-秒
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

# 设置日志记录，日志文件名带时间戳
log_file = f"training_log_{current_time}.txt"
logging.basicConfig(filename=log_file, level=logging.INFO,
                    format='%(asctime)s - %(message)s')  # 加入时间戳格式
logging.info("Training started...")

# 数据预处理
data_transforms = transforms.Compose([
    transforms.Resize((98, 98)),  # 调整图片大小
    transforms.ToTensor(),  # 转为张量
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])  # 标准化
])

# 加载训练集和验证集
train_dataset = datasets.ImageFolder(train_dir, transform=data_transforms)
val_dataset = datasets.ImageFolder(val_dir, transform=data_transforms)

# 创建数据加载器
train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, pin_memory=True)
val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, pin_memory=True)

# 定义模型（以 ResNet18 为例）
from torchvision.models import resnet18, ResNet18_Weights

model = resnet18(weights=ResNet18_Weights.DEFAULT)
model.fc = nn.Linear(model.fc.in_features, num_classes)  # 修改全连接层以适配类别数
device = torch.device("cuda")
model = model.to(device)

# 如果模型已经存在，加载模型参数，设置 weights_only=True
if os.path.exists(model_save_path):
    model.load_state_dict(torch.load(model_save_path, weights_only=True))
    logging.info(f"Model loaded from {model_save_path}")

# 定义损失函数和优化器
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

# 记录训练开始时间
start_time = time.time()

# 训练模型
for epoch in range(num_epochs):
    model.train()
    running_loss = 0.0

    # 训练进度条
    train_progress = tqdm(train_loader, desc=f"Epoch {epoch + 1}/{num_epochs} Training", unit="batch", leave=True)
    for inputs, labels in train_progress:
        inputs, labels = inputs.to(device), labels.to(device)

        # 前向传播
        outputs = model(inputs)
        loss = criterion(outputs, labels)

        # 反向传播和优化
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        running_loss += loss.item()

    # 记录训练日志
    logging.info(f"Epoch {epoch + 1}/{num_epochs}, Training Loss: {running_loss / len(train_loader):.4f}")

    # 验证模型
    model.eval()
    correct = 0
    total = 0
    val_progress = tqdm(val_loader, desc=f"Epoch {epoch + 1}/{num_epochs} Validation", unit="batch", leave=True)
    with torch.no_grad():
        for inputs, labels in val_progress:
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            _, preds = torch.max(outputs, 1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)

    # 记录验证日志
    val_accuracy = correct / total
    logging.info(f"Epoch {epoch + 1}/{num_epochs}, Validation Accuracy: {val_accuracy:.2f}")

# 保存模型
torch.save(model.state_dict(), model_save_path)
logging.info(f"Model saved to {model_save_path}")

# 计算训练时长
end_time = time.time()
elapsed_time = end_time - start_time
logging.info(f"Training completed in {elapsed_time // 60:.0f} minutes and {elapsed_time % 60:.0f} seconds.")
