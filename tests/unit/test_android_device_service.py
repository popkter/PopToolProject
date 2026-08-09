from poptools.infrastructure.android_device_service import (
    parse_adb_devices,
    parse_android_processes,
)


def test_parse_adb_devices_keeps_only_connected_devices() -> None:
    output = """List of devices attached
emulator-5554 device product:sdk_gphone64 model:Pixel_8_Pro device:emu64 transport_id:1
ZX1G22 offline transport_id:2
ABC unauthorized usb:1-2
"""

    devices = parse_adb_devices(output)

    assert len(devices) == 1
    assert devices[0].serial == "emulator-5554"
    assert devices[0].label == "Pixel 8 Pro · emulator-5554"


def test_parse_android_processes_keeps_and_sorts_application_processes() -> None:
    output = """USER PID PPID VSZ RSS WCHAN ADDR S NAME
u0_a100 321 1 0 0 0 0 S com.example.zebra
root 20 2 0 0 0 0 S kthreadd
u0_a101 123 1 0 0 0 0 S com.example.alpha
u0_a102 456 1 0 0 0 0 S com.example.alpha
"""

    assert parse_android_processes(output) == [
        {
            "name": "com.example.alpha",
            "pid": "123",
            "label": "com.example.alpha · PID 123",
        },
        {
            "name": "com.example.zebra",
            "pid": "321",
            "label": "com.example.zebra · PID 321",
        },
    ]
