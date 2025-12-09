"""
文件I/O工具函数

提供数据保存、加载、文件操作等功能
"""

import pickle
import json
from pathlib import Path
from typing import Any, Dict, Union
import logging

logger = logging.getLogger(__name__)


def ensure_dir(path: Union[str, Path]) -> Path:
    """
    确保目录存在，不存在则创建
    
    Args:
        path: 目录路径
        
    Returns:
        Path对象
    """
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    return path


def save_pickle(data: Any, file_path: Union[str, Path]) -> None:
    """
    保存数据为pickle格式
    
    Args:
        data: 要保存的数据
        file_path: 输出文件路径
    """
    file_path = Path(file_path)
    ensure_dir(file_path.parent)
    
    with open(file_path, 'wb') as f:
        pickle.dump(data, f, protocol=pickle.HIGHEST_PROTOCOL)
    
    logger.debug(f"Saved pickle to: {file_path}")


def load_pickle(file_path: Union[str, Path]) -> Any:
    """
    从pickle文件加载数据
    
    Args:
        file_path: 文件路径
        
    Returns:
        加载的数据
    """
    file_path = Path(file_path)
    
    if not file_path.exists():
        raise FileNotFoundError(f"Pickle file not found: {file_path}")
    
    with open(file_path, 'rb') as f:
        data = pickle.load(f)
    
    logger.debug(f"Loaded pickle from: {file_path}")
    return data


def save_json(data: Any, file_path: Union[str, Path], indent: int = 2) -> None:
    """
    保存数据为JSON格式
    
    Args:
        data: 要保存的数据（必须可JSON序列化）
        file_path: 输出文件路径
        indent: 缩进空格数
    """
    file_path = Path(file_path)
    ensure_dir(file_path.parent)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=indent, ensure_ascii=False)
    
    logger.debug(f"Saved JSON to: {file_path}")


def load_json(file_path: Union[str, Path]) -> Any:
    """
    从JSON文件加载数据
    
    Args:
        file_path: 文件路径
        
    Returns:
        加载的数据
    """
    file_path = Path(file_path)
    
    if not file_path.exists():
        raise FileNotFoundError(f"JSON file not found: {file_path}")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    logger.debug(f"Loaded JSON from: {file_path}")
    return data
