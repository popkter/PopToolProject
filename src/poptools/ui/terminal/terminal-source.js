import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";

const terminal = new Terminal({
  allowProposedApi: false,
  convertEol: false,
  cursorBlink: true,
  cursorStyle: "bar",
  fontFamily: '"Cascadia Mono", Consolas, monospace',
  fontSize: 14,
  lineHeight: 1.18,
  scrollback: 10000,
  theme: {
    background: "#141a20",
    foreground: "#e8eef5",
    cursor: "#c5c0ff",
    cursorAccent: "#141a20",
    selectionBackground: "#6660c880",
    black: "#141a20",
    red: "#ff9b93",
    green: "#7ddba4",
    yellow: "#e8ae45",
    blue: "#a8d8ff",
    magenta: "#d5a8ff",
    cyan: "#8ddbd5",
    white: "#dce5ed",
    // PSReadLine uses ANSI bright black for inline history predictions.
    brightBlack: "#9fb3c5",
    brightRed: "#ffb4ab",
    brightGreen: "#9be7b9",
    brightYellow: "#ffd166",
    brightBlue: "#c4e5ff",
    brightMagenta: "#e2c2ff",
    brightCyan: "#a9e9e4",
    brightWhite: "#ffffff"
  }
});
const fitAddon = new FitAddon();
terminal.loadAddon(fitAddon);
terminal.open(document.getElementById("terminal"));

new QWebChannel(qt.webChannelTransport, (channel) => {
  const bridge = channel.objects.terminalBridge;
  let replayWritesPending = 0;
  const inputSubscription = terminal.onData((data) => {
    if (replayWritesPending === 0) {
      bridge.writeInput(data);
    }
  });
  bridge.dataReceived.connect((data) => terminal.write(data));
  bridge.snapshotReceived.connect((data) => {
    replayWritesPending += 1;
    terminal.write(data, () => {
      replayWritesPending -= 1;
      if (replayWritesPending === 0) {
        terminal.focus();
      }
    });
  });
  bridge.resetRequested.connect(() => terminal.reset());

  const fit = () => {
    fitAddon.fit();
    bridge.resizeTerminal(terminal.cols, terminal.rows);
  };
  const resizeObserver = new ResizeObserver(fit);
  resizeObserver.observe(document.getElementById("terminal"));
  window.addEventListener("resize", fit);
  terminal.onResize(({ cols, rows }) => bridge.resizeTerminal(cols, rows));
  fit();
  bridge.terminalReady();
  terminal.focus();

  window.addEventListener("beforeunload", () => {
    resizeObserver.disconnect();
    inputSubscription.dispose();
    terminal.dispose();
  }, { once: true });
});

document.body.addEventListener("mousedown", () => terminal.focus());
