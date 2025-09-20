resource "helm_release" "argo_cd" {
  name             = var.release_name
  repository       = var.helm_repo_url
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = concat([
    file("${path.module}/values.yaml"),
  ],
    var.image_repository == "" && var.image_tag == "" ? [] : [yamlencode({
      global = {
        imageRepository = var.image_repository
        imageTag        = var.image_tag
      }
    })],
    [yamlencode({
      applications = [{
        name = "django-app"
        source = {
          helm = {
            values = join("\n", [
              "config:",
              "  DJANGO_DEBUG: \"false\"",
              "  DJANGO_ALLOWED_HOSTS: \"*\"",
              "  DATABASE_ENGINE: \"${var.django_db_engine}\"",
              "  DATABASE_HOST: \"${length(var.django_db_host_reader) > 0 ? var.django_db_host_reader : var.django_db_host}\"",
              "  DATABASE_PORT: \"${var.django_db_port}\"",
              "  DATABASE_NAME: \"${var.django_db_name}\"",
              "  DATABASE_USER: \"${var.django_db_user}\"",
              "  DATABASE_PASSWORD: \"${var.django_db_password}\"",
            ])
          }
        }
      }]
    })]
  )
}

# Deploy a local Helm chart with Argo CD Applications/Repositories once CRDs are available
resource "helm_release" "argocd_apps" {
  name      = "${var.release_name}-apps"
  chart     = "${path.module}/charts"
  namespace = var.namespace

  values = concat([
    file("${path.module}/charts/values.yaml"),
  ], var.image_repository == "" && var.image_tag == "" ? [] : [yamlencode({
    global = {
      imageRepository = var.image_repository
      imageTag        = var.image_tag
    }
  })])

  depends_on = [helm_release.argo_cd]
}
