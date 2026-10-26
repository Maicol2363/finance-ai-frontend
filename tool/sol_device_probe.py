"""ADB UI probe: locates current controls; never prints editor/credential values."""
import argparse
import re
import subprocess
import xml.etree.ElementTree as ET


def shell(*args):
    return subprocess.run(["adb", "shell", *args], check=True, capture_output=True).stdout


def nodes():
    shell("uiautomator", "dump", "/sdcard/codex-sol-probe.xml")
    return list(ET.fromstring(shell("cat", "/sdcard/codex-sol-probe.xml")).iter("node"))


def tap(label, prefix=False):
    matches = [n for n in nodes() if any((v or "").startswith(label) if prefix else v == label for v in (n.get("text"), n.get("content-desc")))]
    if not matches:
        raise RuntimeError("Control not visible: " + label)
    b = list(map(int, re.findall(r"\d+", matches[-1].get("bounds"))))
    shell("input", "tap", str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2))
    print("Tapped control:", label)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tap")
    parser.add_argument("--editor-count", action="store_true")
    parser.add_argument("--prefix", action="store_true")
    args = parser.parse_args()
    if args.tap:
        tap(args.tap, args.prefix)
    if args.editor_count:
        for n in nodes():
            if n.get("class") == "android.widget.EditText":
                print("Visible editor character count:", len(n.get("text", "")))
