# Recommended Model Context Protocol (MCP) Tools for Development

Based on an investigation into enhancing the AI agent's capabilities, the following MCP tools were identified to address specific gaps in the current toolset.

## 1. Language Server Protocol (LSP) Integration
**Goal:** Semantic understanding of code (Go to Definition, Find References, Refactoring).
*   **Tools:** `mcp-server-lsp`, `mcp-server-python`, `mcp-server-typescript`.
*   **Function:** Wraps standard LSP executables (like `pyright` or `ts-server`) to expose capabilities such as hover information, diagnostics, and symbol navigation to the AI agent.

## 2. Visual/Browser Rendering (Headless Browser)
**Goal:** Verifying UI/UX changes by "seeing" the rendered page.
*   **Tools:** `playwright-mcp`, `puppeteer-mcp`, `chrome-devtools-mcp`.
*   **Function:** Enables the agent to launch a headless browser, navigate to URLs/local files, interact with elements, and take screenshots or inspect the rendered DOM. This effectively acts as a debugger for web applications (console logs, network requests).

## 3. Structured Database Client
**Goal:** Safe and efficient database inspection and querying.
*   **Tools:** `sqlite-mcp`, `postgres-mcp`.
*   **Function:** Provides structured tools to inspect schemas (`LIST_TABLES`, `DESCRIBE_TABLE`) and run queries without relying on potentially risky shell command piping.

## 4. Runtime Debugger
**Status:** Less standardized.
*   **Observation:** While no universal "debugger MCP" exists, the browser MCPs mentioned above serve this role for frontend development. For backend tasks, reliance remains on `run_shell_command` with verbose logging or test execution.

### Recommendation
For this Eleventy web development project, the highest impact upgrades would be:
1.  **`playwright-mcp`**: To verify visual changes and test the site.
2.  **`mcp-server-typescript` / `mcp-server-lsp`**: For better code navigation and error checking in the JavaScript/TypeScript codebase.
