from __future__ import annotations

from typing import Protocol, runtime_checkable

from poptools.domain.models import ToolDefinition


@runtime_checkable
class ToolRepository(Protocol):
    """Persistence boundary for user-owned tools and built-in overrides."""

    def list_tools(self) -> list[ToolDefinition]:
        """Return all custom tools and built-in overrides."""

    def save_tool(self, tool: ToolDefinition) -> None:
        """Create or replace one custom tool or override."""

    def remove_override(self, tool_id: str) -> bool:
        """Remove an override while preserving its built-in definition."""

    def delete_tool(self, tool_id: str) -> bool:
        """Delete a user-created tool."""
