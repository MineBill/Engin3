package gpu

Error :: union #shared_nil {
    InstanceCreationError,
    PipelineCreationError,
    SwapchainCreationError,
}

InstanceCreationError :: enum {
    None,
    FailedValidationCheck,
}

PipelineCreationError :: enum {
    None,
    PipelineCreationFailed,
    PipelineLayoutCreationFailed,
}

ResourceAllocationError :: enum {
    None,
    OutOfMemory,
}
