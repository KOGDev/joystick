# Joystick

This package provides a very basic interface for reading joysticks on linux.
It uses the evdev interface, and should work with most xbox style game pads.
Libc is not required, though the types from `linux/input.h` are translated as part of the build.
