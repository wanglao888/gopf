{
  "listen_port": 443,
  "mode": "tls",
  "services": {
    "YunService": {
      "host": "127.0.0.1",
      "port": 3443
    },
    "example.ProductService": {
      "host": "127.0.0.1", 
      "port": 50052
    },
    "greet.Greeter": {
      "host": "127.0.0.1",
      "port": 50053
    }
  },
  "default_fallback": {
    "host": "127.0.0.1",
    "port": 50051
  },
  "tls": {
    "cert_file": "/etc/V2bX/fullchain.cer",
    "key_file": "/etc/V2bX/cert.key"
  }
}
