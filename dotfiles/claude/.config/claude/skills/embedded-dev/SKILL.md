---
name: embedded-dev
description: Embedded systems development with C, C++, Rust, FPGA, and hardware interfaces. Use when working on microcontrollers, firmware, drivers, RTOS, or hardware design.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
---

# Embedded Development

## Languages

### C/C++
- Follow MISRA-C guidelines for safety-critical code
- Use fixed-width integers (uint8_t, int32_t)
- Minimize dynamic memory allocation
- Use volatile for hardware registers
- Prefer static allocation over heap

### Rust
- Use `#![no_std]` for bare-metal
- Leverage ownership for safe memory management
- Use `embedded-hal` traits for portability
- Prefer `defmt` for efficient logging

## Hardware Interfaces

### GPIO
- Configure pull-up/pull-down resistors appropriately
- Debounce button inputs
- Use interrupts for async events

### Communication Protocols
- **I2C**: Check for ACK/NACK, handle clock stretching
- **SPI**: Configure correct mode (CPOL, CPHA)
- **UART**: Set correct baud rate, parity, stop bits
- **CAN**: Use proper message IDs and filtering

### Memory-Mapped I/O
- Use volatile pointers for register access
- Define register layouts with bitfields or packed structs
- Document register offsets and bit meanings

## RTOS Concepts
- Use semaphores/mutexes for synchronization
- Avoid priority inversion
- Size stacks appropriately
- Use message queues for inter-task communication

## FPGA/HDL
- Synchronize signals across clock domains
- Use proper reset strategies
- Document timing constraints
- Simulate before synthesis

## Build Systems
- CMake for cross-compilation
- Makefiles with proper dependency tracking
- Linker scripts for memory layout

## Debugging
- Use JTAG/SWD for hardware debugging
- Implement logging over UART or RTT
- Use logic analyzers for protocol debugging
- Check for stack overflows

## Best Practices
- Document hardware connections and pin assignments
- Version control hardware abstraction layers
- Test on actual hardware, not just simulators
- Consider power consumption and timing constraints
