import os
import torch
from torch import nn, optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from tqdm import tqdm
import logging
from datetime import datetime
import time

# 设置路径
train_dir = "G:/database/shipsEar/shipsEar_Enhanced/train_cb_pic_rgb"\
            #"G:/database/shipsEar/shipsEar_reclassified/train_origin_pic_rgb" # 训练集路径

val_dir = "G:/database/shipsEar/shipsEar_Enhanced/val_cb_pic_rgb"
          #"G:/database/shipsEar/shipsEar_reclassified/val_origin_pic_rgb"  # 验证集路径
batch_size = 64
num_epochs = 16
learning_rate = 0.001
num_classes = 5  # 类别数
model_save_path = "model.pth"

# 获取当前时间戳，格式为：年-月-日_时-分-秒
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
log_file = f"training_log_{current_time}.txt"
logging.basicConfig(filename=log_file, level=logging.INFO,
                    format='%(asctime)s - %(message)s')
logging.info("Training started...")

# 数据预处理
data_transforms = transforms.Compose([
    transforms.Resize((98, 98)),  # 调整图片大小
    transforms.ToTensor(),        # 转为张量
    transforms.Lambda(lambda x: (x - x.mean(dim=(1, 2), keepdim=True)) / (x.std(dim=(1, 2), keepdim=True) + 1e-8))
])

# 加载训练集和验证集
train_dataset = datasets.ImageFolder(train_dir, transform=data_transforms)
val_dataset = datasets.ImageFolder(val_dir, transform=data_transforms)

train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, pin_memory=True)
val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, pin_memory=True)


# 定义自定义卷积神经网络
class MyCNN(nn.Module):
    def __init__(self, num_classes=5):
        super(MyCNN, self).__init__()
        # 第一层卷积：输入3通道，输出16个特征图，卷积核大小3，stride=1，padding=1保证尺寸不变
        self.conv1 = nn.Conv2d(in_channels=3, out_channels=16, kernel_size=3, stride=1, padding=1)
        # 第二层卷积：输入16通道，输出32个特征图
        self.conv2 = nn.Conv2d(in_channels=16, out_channels=32, kernel_size=3, stride=1, padding=1)
        # 池化层：2x2最大池化
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2)
        # 经过两次池化后，98×98的图像尺寸将变为大约24×24
        # 全连接层输入特征数：32 * 24 * 24
        self.fc1 = nn.Linear(32 * 24 * 24, 128)
        # 输出层
        self.fc2 = nn.Linear(128, num_classes)

    def forward(self, x):
        # 第一层卷积、ReLU激活、池化
        x = self.pool(torch.relu(self.conv1(x)))
        # 第二层卷积、ReLU激活、池化
        x = self.pool(torch.relu(self.conv2(x)))
        # 展平操作
        x = x.view(x.size(0), -1)
        # 全连接层和ReLU激活
        x = torch.relu(self.fc1(x))
        # 输出层
        x = self.fc2(x)
        return x


# 选择设备
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = MyCNN(num_classes=num_classes).to(device)

# 定义损失函数和优化器
criterion = nn.CrossEntropyLoss()
optimizer = optim.AdamW(model.parameters(), lr=learning_rate, weight_decay=1e-4)

# 记录训练开始时间
start_time = time.time()

# 训练模型
for epoch in range(num_epochs):
    model.train()
    running_loss = 0.0
    train_progress = tqdm(train_loader, desc=f"Epoch {epoch + 1}/{num_epochs} Training", unit="batch", leave=True)
    for inputs, labels in train_progress:
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()

    avg_loss = running_loss / len(train_loader)
    logging.info(f"Epoch {epoch + 1}/{num_epochs}, Training Loss: {avg_loss:.4f}")

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
    val_accuracy = correct / total
    logging.info(f"Epoch {epoch + 1}/{num_epochs}, Validation Accuracy: {val_accuracy:.2f}")

# 保存模型参数
torch.save(model.state_dict(), model_save_path)
logging.info(f"Model saved to {model_save_path}")

# 记录训练时长
end_time = time.time()
elapsed_time = end_time - start_time
logging.info(f"Training completed in {elapsed_time // 60:.0f} minutes and {elapsed_time % 60:.0f} seconds.")
