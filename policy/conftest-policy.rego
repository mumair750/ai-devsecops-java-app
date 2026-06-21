package main

deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.containers[0].securityContext.runAsNonRoot
    msg = sprintf("Container '%s' must run as non-root", [input.spec.template.spec.containers[0].name])
}

deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.containers[0].securityContext.privileged == true
    msg = sprintf("Container '%s' cannot be privileged", [input.spec.template.spec.containers[0].name])
}