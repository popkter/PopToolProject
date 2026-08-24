from __future__ import annotations

from typing import Any

from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt

from poptools.domain.models import ToolDefinition

_EMPTY_INDEX = QModelIndex()


class ToolListModel(QAbstractListModel):
    IdRole = Qt.UserRole + 1
    TitleRole = Qt.UserRole + 2
    DescriptionRole = Qt.UserRole + 3
    IconRole = Qt.UserRole + 4
    SelectedRole = Qt.UserRole + 5
    KindRole = Qt.UserRole + 6
    RunningRole = Qt.UserRole + 7

    def __init__(self) -> None:
        super().__init__()
        self._tools: list[ToolDefinition] = []
        self._display_tools: list[ToolDefinition] = []
        self._selected_id = ""
        self._running_ids: set[str] = set()
        self._filter_query = ""

    def roleNames(self) -> dict[int, bytes]:
        return {
            self.IdRole: b"toolId",
            self.TitleRole: b"title",
            self.DescriptionRole: b"description",
            self.IconRole: b"iconName",
            self.SelectedRole: b"selected",
            self.KindRole: b"executorKind",
            self.RunningRole: b"running",
        }

    def rowCount(self, parent: QModelIndex = _EMPTY_INDEX) -> int:
        return 0 if parent.isValid() else len(self._display_tools)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole) -> Any:
        if not index.isValid() or not 0 <= index.row() < len(self._display_tools):
            return None
        tool = self._display_tools[index.row()]
        values = {
            self.IdRole: tool.id,
            self.TitleRole: tool.title,
            self.DescriptionRole: tool.description,
            self.IconRole: tool.presentation.icon,
            self.SelectedRole: tool.id == self._selected_id,
            self.KindRole: tool.executor.kind.value,
            self.RunningRole: tool.id in self._running_ids,
        }
        return values.get(role)

    def set_tools(
        self,
        tools: list[ToolDefinition],
        selected_id: str = "",
        running_ids: set[str] | None = None,
    ) -> None:
        self.beginResetModel()
        self._tools = list(tools)
        self._display_tools = self._filtered_tools()
        self._selected_id = selected_id
        self._running_ids = set(running_ids or ())
        self.endResetModel()

    def set_filter(self, query: str) -> None:
        normalized = query.strip().casefold()
        if normalized == self._filter_query:
            return
        self.beginResetModel()
        self._filter_query = normalized
        self._display_tools = self._filtered_tools()
        self.endResetModel()

    def select(self, tool_id: str) -> None:
        if tool_id == self._selected_id:
            return
        previous = self._selected_id
        self._selected_id = tool_id
        changed_roles = [self.SelectedRole]
        for candidate in (previous, tool_id):
            row = next(
                (i for i, tool in enumerate(self._display_tools) if tool.id == candidate),
                -1,
            )
            if row >= 0:
                index = self.index(row, 0)
                self.dataChanged.emit(index, index, changed_roles)

    def _filtered_tools(self) -> list[ToolDefinition]:
        if not self._filter_query:
            return list(self._tools)
        return [
            tool
            for tool in self._tools
            if self._filter_query in tool.title.casefold()
            or self._filter_query in tool.description.casefold()
            or self._filter_query in tool.executor.kind.value.casefold()
        ]
