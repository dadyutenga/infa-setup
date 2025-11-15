#!/bin/bash
### MODULE: Nginx

run_nginx() {
    if ! command -v nginx >/dev/null 2>&1; then
        update_package_index
        install_packages nginx
    else
        log_info "Nginx already installed. Ensuring latest configuration."
    fi

    local nginx_user="www-data"
    if [[ "$OS_FAMILY" == "rhel" ]]; then
        nginx_user="nginx"
    fi

    local repo_log_dir="$BASE_DIR/logs/nginx"
    mkdir -p "$repo_log_dir"
    if id "$nginx_user" >/dev/null 2>&1; then
        chown "$nginx_user":"$nginx_user" "$repo_log_dir" || true
        chmod 750 "$repo_log_dir"
    fi

    local web_root_base="$BASE_DIR/web"
    mkdir -p "$web_root_base"

    local template_dir="$MODULES_DIR/nginx-templates"
    if [[ ! -d "$template_dir" ]]; then
        log_error "Nginx template directory missing: $template_dir"
        return 1
    fi

    local nginx_conf_dir="/etc/nginx"
    local sites_available="$nginx_conf_dir/sites-available"
    local sites_enabled="$nginx_conf_dir/sites-enabled"
    local use_sites_available=true

    if [[ "$OS_FAMILY" == "rhel" ]]; then
        sites_available="$nginx_conf_dir/conf.d"
        sites_enabled="$sites_available"
        use_sites_available=false
    else
        mkdir -p "$sites_available" "$sites_enabled"
    fi

    local subdomains=(api app admin billing files)
    for sub in "${subdomains[@]}"; do
        local template_file="$template_dir/${sub}.conf"
        if [[ ! -f "$template_file" ]]; then
            log_error "Missing template for $sub: $template_file"
            return 1
        fi
        local full_domain="${sub}.${PRIMARY_DOMAIN}"
        local site_root="$web_root_base/$full_domain"
        mkdir -p "$site_root/public"
        if [[ ! -f "$site_root/public/index.html" ]]; then
            cat <<HTML > "$site_root/public/index.html"
<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\" />
<title>${full_domain}</title>
</head>
<body>
<h1>${full_domain}</h1>
<p>Provisioned by infra-setup toolkit.</p>
</body>
</html>
HTML
            if id "$nginx_user" >/dev/null 2>&1; then
                chown -R "$nginx_user":"$nginx_user" "$site_root" || true
            fi
            chmod -R 755 "$site_root"
        fi

        local config_target="$sites_available/${full_domain}.conf"
        local access_log="$repo_log_dir/${full_domain}-access.log"
        local error_log="$repo_log_dir/${full_domain}-error.log"

        sed -e "s/{{FULL_DOMAIN}}/$full_domain/g" \
            -e "s#{{ROOT_PATH}}#$site_root/public#g" \
            -e "s#{{ACCESS_LOG}}#$access_log#g" \
            -e "s#{{ERROR_LOG}}#$error_log#g" "$template_file" > "$config_target"

        if [[ "$use_sites_available" == true ]]; then
            ln -sf "$config_target" "$sites_enabled/${full_domain}.conf"
        fi
    done

    run_cmd "Testing Nginx configuration" nginx -t
    run_cmd "Enabling and restarting Nginx" systemctl enable --now nginx

    log_info "Nginx configured with templates for ${subdomains[*]}."
    return 0
}
