provider "google" {
  credentials = var.gcp_svc_key
  project     = "cloud-resume-460323"
  region      = "us-central1"
}

resource "google_storage_bucket" "staticsite" {
  provider = google
  name     = "gins0n.dev"
  location = "us-central1"

  website {
    main_page_suffix = "Adam-Rioux-Resume.html"
  }
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_object" "staticsite_src" {
  name   = "Adam-Rioux-Resume.html"
  source = "Adam-Rioux-Resume.html"
  bucket = google_storage_bucket.staticsite.name
}
resource "google_storage_default_object_access_control" "public_rule" {
  bucket = google_storage_bucket.staticsite.name
  role   = "READER"
  entity = "allUsers"
}

# Reserve an external IP
resource "google_compute_global_address" "staticsite" {
  provider = google
  name     = "website-lb-ip"
}

# Get the managed DNS zone
data "google_dns_managed_zone" "gcp_gins0n_dev" {
  provider = google
  name     = "gcp-gins0n-dev"
}

# Add the IP to the DNS
resource "google_dns_record_set" "staticsite" {
  provider     = google
  name         = "website.${data.google_dns_managed_zone.gcp_gins0n_dev.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.gcp_gins0n_dev.name
  rrdatas      = [google_compute_global_address.staticsite.address]
}

# Add the bucket as a CDN backend
resource "google_compute_backend_bucket" "staticsite" {
  provider    = google
  name        = "staticsite"
  description = "Contains files needed by the website"
  bucket_name = google_storage_bucket.staticsite.name
  enable_cdn  = true
}

# Create HTTPS certificate
resource "google_compute_managed_ssl_certificate" "staticsite" {
  provider = google-beta
  project  = "cloud-resume-460323"
  name     = "staticsite-cert"
  managed {
    domains = [google_dns_record_set.staticsite.name]
  }
}

# GCP URL MAP
resource "google_compute_url_map" "staticsite" {
  provider        = google
  name            = "staticsite-url-map"
  default_service = google_compute_backend_bucket.staticsite.self_link
}

# GCP target proxy
resource "google_compute_target_https_proxy" "staticsite" {
  provider         = google
  name             = "staticsite-target-proxy"
  url_map          = google_compute_url_map.staticsite.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.staticsite.self_link]
}

# GCP forwarding rule
# comment adding for testing
resource "google_compute_global_forwarding_rule" "default" {
  provider              = google
  name                  = "staticsite-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.staticsite.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.staticsite.self_link
}