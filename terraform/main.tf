provider "google" {
  credentials = file(var.gcp_svc_key)
  project     = "cloud-resume-460323"
  region      = "us-central1"
}

resource "google_storage_bucket" "static_site" {
  provider = google
  name          = "gins0n.dev"
  location      = "US"
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
   response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_object" "static_site_src" {
  name   = "index.html"
  source = "public/index.html"
  bucket = google_storage_bucket.static_site.name
}
resource "google_storage_default_object_access_control" "public_rule" {
  bucket = google_storage_bucket.static_site.name
  role   = "READER"
  entity = "allUsers"
}