import Darwin

/// The current task's port. `mach_task_self_` is set once at process launch and never
/// changes, but C imports it as a mutable global; this is the only place it is read.
func currentTaskPort() -> mach_port_t {
    mach_task_self_
}
