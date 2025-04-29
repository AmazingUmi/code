import os
import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from torchvision.models import resnet50
import logging
from tqdm import tqdm
from sklearn.metrics import classification_report, confusion_matrix

# 配置参数
num_classes = 5  # 与训练时相同的类别数
batch_size = 128  # 与训练时相同的批次大小

# 1. 加载训练好的模型
model_save_path = "best_model_resnet50.pth"  # 确保这是你保存的模型路径
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = resnet50(weights=None)  # 不加载预训练权重
model.fc = torch.nn.Linear(model.fc.in_features, num_classes)  # 替换最后的全连接层
model.load_state_dict(torch.load(model_save_path, map_location=device, weights_only=True))
model = model.to(device)
model.eval()  # 设置为评估模式

# 2. 准备新的数据集
new_test_dir = "G:/database/shipsEar/shipsEar_classified/origin_pic_rgb"  # 新数据集的路径
#G:/database/MergedDataset_single_env/Deep/test

# 定义归一化函数
def normalize_tensor(x):
    mean = x.mean(dim=(1,2), keepdim=True)
    std = x.std(dim=(1,2), keepdim=True) + 1e-8
    return (x - mean) / std

data_transforms = transforms.Compose([
    transforms.Resize((98, 98)),
    transforms.ToTensor(),
    transforms.Lambda(normalize_tensor)
])

new_test_dataset = datasets.ImageFolder(new_test_dir, transform=data_transforms)
new_test_loader = DataLoader(
    new_test_dataset, 
    batch_size=batch_size, 
    shuffle=False, 
    pin_memory=True, 
    num_workers=0  # 设置为0避免多进程问题
)

# 3. 进行推理
correct = total = 0
all_preds = []
all_labels = []

with torch.no_grad():
    for inputs, labels in tqdm(new_test_loader, desc="Test", leave=False):
        inputs, labels = inputs.to(device), labels.to(device)
        outputs = model(inputs)
        preds = outputs.argmax(dim=1)
        correct += (preds == labels).sum().item()
        total += labels.size(0)
        all_preds.extend(preds.cpu().tolist())
        all_labels.extend(labels.cpu().tolist())

test_acc = correct / total
print(f"Test Accuracy: {test_acc:.4f}")
logging.info(f"Test Accuracy: {test_acc:.4f}")

# 可选：打印分类报告和混淆矩阵
print(classification_report(all_labels, all_preds, digits=4))
cm = confusion_matrix(all_labels, all_preds)
print("Confusion Matrix:\n", cm)