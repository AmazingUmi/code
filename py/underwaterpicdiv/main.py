import os
import torch
from torch import nn, optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader, random_split
from tqdm import tqdm  # 导入 tqdm 用于显示进度条

# 设置路径
data_dir = "D:/database/shipsEar/shipsEar_png/"  # 替换为你的图片总目录路径
batch_size = 32
num_epochs = 10
learning_rate = 0.001
num_classes = 5  # 修改为你的类别数量

# 数据预处理
data_transforms = transforms.Compose([
    transforms.Resize((98, 32)),  # 调整图片大小
    transforms.ToTensor(),  # 转为张量
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])  # 标准化
])

# 加载数据
dataset = datasets.ImageFolder(data_dir, transform=data_transforms)

# 自动划分训练集和验证集（8:2）
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = random_split(dataset, [train_size, val_size])

# 创建数据加载器
train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, pin_memory=True)
val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, pin_memory=True)

# 定义模型（以 ResNet18 为例）
from torchvision.models import resnet18, ResNet18_Weights

model = resnet18(weights=ResNet18_Weights.DEFAULT)
model.fc = nn.Linear(model.fc.in_features, num_classes)  # 修改全连接层以适配类别数
device = torch.device("cuda")
model = model.to(device)

# 定义损失函数和优化器
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

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

    # 确保进度条刷新后再打印日志
    train_progress.close()
    tqdm.write(f"Epoch {epoch + 1}/{num_epochs}, Loss: {running_loss / len(train_loader):.4f}")

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

    # 确保验证进度条刷新后再打印日志
    val_progress.close()
    tqdm.write(f"Validation Accuracy: {correct / total:.2f}")

# 保存模型
torch.save(model.state_dict(), "model.pth")

