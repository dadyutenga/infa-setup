#!/bin/bash
### MODULE: OS Detection

run_os_detect() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "/etc/os-release not found. Unsupported system."
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="$ID"
    OS_VERSION_ID="$VERSION_ID"
    OS_NAME="$PRETTY_NAME"

    case "$ID" in
        ubuntu|debian)
            OS_FAMILY="debian"
            PACKAGE_MANAGER="apt"
            ;;
        almalinux)
            OS_FAMILY="rhel"
            PACKAGE_MANAGER="dnf"
            ;;
        *)
            if [[ "$ID_LIKE" == *"debian"* ]]; then
                OS_FAMILY="debian"
                PACKAGE_MANAGER="apt"
            elif [[ "$ID_LIKE" == *"rhel"* || "$ID_LIKE" == *"fedora"* ]]; then
                OS_FAMILY="rhel"
                PACKAGE_MANAGER="dnf"
            else
                log_error "Unsupported distribution: $ID"
                return 1
            fi
            ;;
    esac

    if [[ "$OS_FAMILY" == "rhel" && "${OS_VERSION_ID%%.*}" -lt 9 ]]; then
        log_error "AlmaLinux version $OS_VERSION_ID is not supported. Require 9+."
        return 1
    fi

    if [[ "$OS_ID" == "ubuntu" ]]; then
        if [[ "${OS_VERSION_ID%%.*}" -lt 20 ]]; then
            log_error "Ubuntu $OS_VERSION_ID is not supported. Require 20.04+."
            return 1
        fi
    elif [[ "$OS_ID" == "debian" ]]; then
        if [[ "${OS_VERSION_ID%%.*}" -lt 11 ]]; then
            log_error "Debian $OS_VERSION_ID is not supported. Require 11+."
            return 1
        fi
    fi

    export OS_ID OS_VERSION_ID OS_NAME OS_FAMILY PACKAGE_MANAGER

    log_info "OS detection complete: $OS_NAME"
    return 0
}
