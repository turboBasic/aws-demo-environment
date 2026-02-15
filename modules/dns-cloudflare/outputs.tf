output "acm_validation_dns_record_id" {
  description = "ID of the ACM certificate validation DNS record"
  value       = cloudflare_dns_record.acm_validation.id
}

output "apex_dns_record_id" {
  description = "ID of the apex domain (CNAME) DNS record"
  value       = cloudflare_dns_record.demo.id
}

output "www_dns_record_id" {
  description = "ID of the www subdomain (CNAME) DNS record"
  value       = cloudflare_dns_record.www.id
}

output "zone_setting_ssl_id" {
  description = "ID of the Cloudflare SSL zone setting"
  value       = cloudflare_zone_setting.ssl.id
}

output "redirect_ruleset_id" {
  description = "ID of the www to apex redirect ruleset"
  value       = cloudflare_ruleset.redirect_www.id
}
