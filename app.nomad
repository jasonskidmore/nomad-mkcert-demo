job "example-app"{
  datacenters = ["dc1"]
  type = "service"

  group "web" {


    network {
      port "http" {
        to = 8000
      }
      port "lb" {
        to = 443
      }
    }

    service {
      name = "app-server"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "5s"
        timeout  = "5s"
      }
    }

  task "app-server" {
      driver = "docker"
      config {
        image = "jrs2995/hello_django:0.0.5"
        ports = ["http"]
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx"

        ports = ["lb"]

        volumes = [
          "local:/etc/nginx/conf.d",
          "secrets/certificate.crt:/secrets/certificate.crt",
          "secrets/certificate.key:/secrets/certificate.key",
        ]
      }

      template {
        data = <<EOF
upstream backend {
{{ range service "app-server" }}
  server {{ .Address }}:{{ .Port }};
{{ else }}server 127.0.0.1:65535; # force a 502
{{ end }}
}

server {
   listen 443 ssl;
   ssl_certificate      /secrets/certificate.crt;
   ssl_certificate_key  /secrets/certificate.key;
   ignore_invalid_headers off;
   proxy_http_version 1.1;
   client_max_body_size 50M;
   proxy_read_timeout 90s;
   proxy_send_timeout 90s;

   location / {
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header Host $http_host;
      proxy_pass http://backend;
   }
}

EOF
destination   = "local/load-balancer.conf"
}
template {
  # Warning: Fetch certificate from a secret store like vault in a production setting
  data = <<EOF
-----BEGIN CERTIFICATE-----
MIIEjjCCAvagAwIBAgIQIpPgIqCZEFTPrZLdEXggiTANBgkqhkiG9w0BAQsFADCB
rTEeMBwGA1UEChMVbWtjZXJ0IGRldmVsb3BtZW50IENBMUEwPwYDVQQLDDhqc2tp
ZG1vcmVASmFzb25Ta2lkbW9yZS1NYWNCb29rUHJvLmhvbWUgKGphc29uIHNraWRt
b3JlKTFIMEYGA1UEAww/bWtjZXJ0IGpza2lkbW9yZUBKYXNvblNraWRtb3JlLU1h
Y0Jvb2tQcm8uaG9tZSAoamFzb24gc2tpZG1vcmUpMB4XDTIxMDgxNzE4MjQxMloX
DTIzMTExNzE5MjQxMlowbDEnMCUGA1UEChMebWtjZXJ0IGRldmVsb3BtZW50IGNl
cnRpZmljYXRlMUEwPwYDVQQLDDhqc2tpZG1vcmVASmFzb25Ta2lkbW9yZS1NYWNC
b29rUHJvLmhvbWUgKGphc29uIHNraWRtb3JlKTCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBALSbCzYxgAKvrRpBeAI1Pnv7EBfIzFHav5AY+aQaE6Hq1eif
VepKpyXtsVIyR/wUnMKvyVdGINdQmPtuVekgiRMSAy/FL+yFHKkLqiw5JpSNIMpv
3ROSqflW0OX6YJjO/Wd/fNLnWic7exLOr0x9DamOBJY9TjRRnKMEx6G35lfE1gZT
qLAptUFqhFKR+5LK9lmnpfJ6UtBKKEC+0YgSEDer3/Ut32EFqNVOfht31m0CP4dT
U7pC7jqc1uM8sbxVaD4MV/BSQWgpQHHOq3YCqjAUZvWhU/3vgFONr5sQInioKkQK
H0mWFOz8LruqC4eA2aJvxQWn/Uj5gPIkuSHgTfkCAwEAAaNqMGgwDgYDVR0PAQH/
BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMBMB8GA1UdIwQYMBaAFCVhMAxtnuKn
5bavGdRaJM+KbiP2MCAGA1UdEQQZMBeCCWxvY2FsaG9zdIcEfwAAAYcEwKgCiDAN
BgkqhkiG9w0BAQsFAAOCAYEAqC78nIKuJToHCmiAHYIDAlEGs7JsTSGuqtWlwznh
z4Ne76X2Ud2Swv2taMIEWsdvD5qoiIMFTt2m+oGzPVTdGYM8ZIvzHwodd/4orgll
eEUwqLwBsIzGTCG8cYHVT9o4RYGE89+aMOXshDq7YDq0k9/AQRsWm9bO/rtYWga3
jrBkAZQQ+EwQv4yBNLC1zimV81QZHPunNSZcstnwRgLRkPLMYIX/gnEUPrM7Q681
7ai2tA080HrmCzMWYl/sRyaWbzi1vZM2X4Q49i+bsaxmu2AOr7nLpxw3d64vc6hK
v3Mgn1dL62DJkhPQOV3rO2P5XfFMnN/ylb81TOlnxH4oLJUGVorsH2BDDQKB2+kt
aPGNlAbwZvMeFvWjxQvOlETYmwFgbLvvp9Yx9VM2H4C25XFMNiEcbmH5Csze6fNU
XqmDs1og07q9RccuhGg3rqgMmt2ZxdBRB/OmLHagJscsM6qHgdPBHDfyXxbT1cAA
2iHbc1JUWOxlX90X1VZVHx4e
-----END CERTIFICATE-----
  EOF
  destination = "secrets/certificate.crt"
}
template {
  # Warning: Fetch certificate from a secret store like vault in a production setting
  data = <<EOF
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC0mws2MYACr60a
QXgCNT57+xAXyMxR2r+QGPmkGhOh6tXon1XqSqcl7bFSMkf8FJzCr8lXRiDXUJj7
blXpIIkTEgMvxS/shRypC6osOSaUjSDKb90Tkqn5VtDl+mCYzv1nf3zS51onO3sS
zq9MfQ2pjgSWPU40UZyjBMeht+ZXxNYGU6iwKbVBaoRSkfuSyvZZp6XyelLQSihA
vtGIEhA3q9/1Ld9hBajVTn4bd9ZtAj+HU1O6Qu46nNbjPLG8VWg+DFfwUkFoKUBx
zqt2AqowFGb1oVP974BTja+bECJ4qCpECh9JlhTs/C67qguHgNmib8UFp/1I+YDy
JLkh4E35AgMBAAECggEAEIxoUZXlidl4/f/jtCgWypttlRBUEGf/x39SWIP/KoXv
Bbqbz7T5bdNCvSpYSDPHTVt4EmQdnD0JV3h7rLnLdZDf89+YjY6A2shz1kuCSnhH
+eSYGDQHGQ6oY3o2oanNtE8NK/IA47lihI2lqFeJCfE2YGHLqaWUuac1d473LzF1
e676+uwWU28NAHjMC1/I9Uw+Lwut1FQMkPEfJh+V0hfg0OtvARltn7xjuBXpGGmI
RMCNDmIiR1xsLLe3FU+Zxesis85WZ99wuqJrz47yBJnN6NhXnDyGXc6QLnqynStF
lB7liCQbt1FvSfnkAfKcdIJfAKk0bwp6Z74V3nrDtQKBgQDHsE7KYiWSWy8xn6c7
Wwx07y/nL0UuMOJQZf4O1UOdnm0qVuniXtxHAH4iNNkkVoZgP0TbSSowrUBBXPyx
GXDMB6Cyhl4yL8K/pP7100Km2Qnpo+xYIBOZLy/OYmOU1fx99/BP0ZtRQ8pty66q
qSPDbBwTC2cGksuC7QBIRv9SOwKBgQDniR0uthNuKen22WD81Pme6cF5/HeRVO8o
rvvtvtb57G5f+xsF5UgsczsLmy23Ja0q2rcgn9rau8HPaVnNhTw2r4oZ145q9Byj
7Mc/47ALX77MKLpLF9/MnIEX9TyZk+zS/VdBt/EM7Piv8+V3eFIn8Q8JimF8u8Sh
ttnEhA4JWwKBgGi7swd45KXXh3AqgWajQWxPSzug0lMAtqJebBrRhg40WqM7RJ5D
DJt8yasdNspVS1NNu8qbnDI9nBbsM2ibpEqOsZ0Q1nTSEf28BzFdpXanHQjavgoW
gND2K8e+WOZmOXDEStlCYYkE2jYt/yVpYuWLXUorz9Rlx7GapmxCOIWjAoGAMkbU
3mrNJ1PUqTSk2eIJXleWGr4W3Kkb0bLFo+eX2OddRFxLjukt1fEjti55K9bzlmWt
9Fih9nNk73wJ8xXmcF2H2Hq1Q0ZE3dexoI75kE63KLADXAEQKOcnJSOsiBDWES7P
/sZJgqwGiHamsl2fQWsX/9NbvfEsDo2dFg4y2hcCgYEAk1EfTF7R0fHR24pYzwVT
ks8fEEu2TJ3wbfXHaMNlGCQNRzHKonyNEeyT2wU1iTYNfZeUwh873UPyyeD3wViC
y2HoBWpnOUZFSHMCCZ1N81t3/WK3iyGtyBE2X4beJMr/AIc47UtrfKbiB1I+ZoXY
e7saYDEjHNC2wyjnPtjD3is=
-----END PRIVATE KEY-----
  EOF
  destination = "secrets/certificate.key"
}
    }
  }
}
