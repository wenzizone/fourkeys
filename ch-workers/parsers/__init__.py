from typing import Dict, Type

from .argocd import ArgoCDParser
from .base import BaseParser
from .circleci import CircleCIParser
from .github import GitHubParser

PARSERS: Dict[str, Type[BaseParser]] = {
    "github": GitHubParser,
    "circleci": CircleCIParser,
    "argocd": ArgoCDParser,
}

__all__ = [
    "BaseParser",
    "GitHubParser",
    "CircleCIParser",
    "ArgoCDParser",
    "PARSERS",
]
