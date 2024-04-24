package gpu

InstanceCreationError :: enum {
    None,
    FailedValidationCheck,
}

PipelineCreationError :: enum {
    None,
    PipelineCreationFailed,
    PipelineLayoutCreationFailed,
}

Error :: union #shared_nil {
    InstanceCreationError,
    PipelineCreationError,
    SwapchainCreationError,
}
