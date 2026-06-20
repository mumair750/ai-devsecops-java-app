cat > policy/security.rego << 'EOF'
package kubernetes.deny

# Rule 1: No root containers
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.containers[0].securityContext.runAsNonRoot
    msg = sprintf("❌ Container '%s' must run as non-root", [input.spec.template.spec.containers[0].name])
}

# Rule 2: No privileged containers
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.containers[0].securityContext.privileged == true
    msg = sprintf("❌ Container '%s' cannot be privileged", [input.spec.template.spec.containers[0].name])
}

# Rule 3: CPU limits required
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.containers[0].resources.limits.cpu
    msg = sprintf("❌ Container '%s' must have CPU limits", [input.spec.template.spec.containers[0].name])
}

# Rule 4: Memory limits required
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.containers[0].resources.limits.memory
    msg = sprintf("❌ Container '%s' must have Memory limits", [input.spec.template.spec.containers[0].name])
}

# Rule 5: No latest tag
deny[msg] {
    input.kind == "Deployment"
    contains(input.spec.template.spec.containers[0].image, ":latest")
    msg = sprintf("❌ Container '%s' uses 'latest' tag - not allowed", [input.spec.template.spec.containers[0].name])
}
EOF