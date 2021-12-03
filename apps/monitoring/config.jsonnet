// TODO: convert file to yaml and figure out how to merge configuration as `std.mergePatch` may not be enough

{
  common+: {
    namespace: 'monitoring',
    ruleLabels: {
      role: 'alert-rules',
    },
    baseDomain: 'uberwald.thaum.xyz',
  },
  alertmanager+: {
    resources+: {
      requests: { memory: '30Mi' },
    },
    mixin+: {
      _config+: {
        runbookURLPattern: 'https://runbooks.thaum.xyz/runbooks/alertmanager/%s',
      },
    },
  },
  prometheus+: {
    // version: '2.31.1',  // application-version-from-github: prometheus/prometheus
    // image: 'quay.io/prometheus/prometheus:v2.31.1',  // application-image-from-github: prometheus/prometheus
    externalLabels: {
      cluster: 'uberwald',
    },
    enableFeatures: [
      'remote-write-receiver',
      'memory-snapshot-on-shutdown',
      'new-service-discovery-manager',
    ],
    resources: {
      requests: { cpu: '140m', memory: '1900Mi' },
      limits: { cpu: '1' },
    },
    mixin+: {
      _config: {
        runbookURLPattern: 'https://runbooks.thaum.xyz/runbooks/prometheus/%s',
      },
    },
    // More in https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
    // Password stored in bitwarden
    remoteWriteAuth: 'AgDGeT9BN6FzkFxAGIEfp/DSRL+jQ+CFoLiwAXUWC6QtfDFgWyQGauDRQqWvsPCWrCFNNSi0qsb8ObppQpVAftJLXZL+HI44me3AviYfMUPif7r5XKvcjhMkR+X7Cpk3/67ewlPDO5kHMuVosyVVbtGF4uznwPsi1mH+pRHsdSo76muFNNY/Cvr5stEtk+6UYakFZvti0Pe24nOI+mf0weBRLkyo45uZWOG4Lgok4AO84h9lKEJb6ROWYHs5neJua6JevdtQSOUo5xKyBCHNpkCrtkn0QkX6pSwwTL90s7em1anJL5pXy/oHSfaqa2VkQ6pDvgFylrXAr049sen8v5zaQoemQ9m3jKD8b5sZbBRhV5AxEGd8AH4f0S33zeVmwNyc0DiSE7riFPPTxvXPmW0JVubYSj7rr1aANNKW8UVzTRNutsX/SyxN8FgLPb41miuNVN0GOH8qA58l3t4LxaoDeAeLfg8VgOZ6yf2g1yhEzpSG98VIvt5hDxwlQvOlpUqXjckuV+bWDhiQYUQZFmzLWNJ/ki7E9mGM8kJ0nIQHiB3zg1cfEIoeSB0930upjll48/r57+m/TSjrymVgMzGwzJ/dd7tjeBagpVBsxnPdLY4PTKA6g5SJsDTDLzdWKsjHhoQR62WIUhC8QV8m8m9xYSAyfnaNVUVwh5b2q+5Q3agilaquFO3Ay1AZbS0x4n3K6WkJQHF2h1qR97PmW5YFrDH3gg6YzNyEDDEUQlNv6KL0D+NUzXXotxMH67A3',
  },
  prometheusOperator+: {
    // version: '0.52.0',
    // image: 'quay.io/prometheus-operator/prometheus-operator:v0.52.0',
    // configReloaderImage: 'quay.io/prometheus-operator/prometheus-config-reloader:v0.52.0',
    mixin+: {
      _config: {
        prometheusOperatorSelector: 'job="prometheus-operator"',
        runbookURLPattern: 'https://runbooks.thaum.xyz/runbooks/prometheus-operator/%s',
      },
    },
  },
  blackboxExporter+: {
    // Using only HTTP module
    modules: {
      http_2xx: {
        http: {
          preferred_ip_protocol: 'ip4',
        },
        prober: 'http',
      },
    },
    resources: {
      requests: { cpu: '30m', memory: '16Mi' },
      limits: { cpu: '64m', memory: '42Mi' },
    },
    replicas: 2,
    probes: {
      promDemo: {
        staticConfig: {
          static: [
            'https://demo.do.prometheus.io/',
            'https://prometheus.demo.do.prometheus.io/-/healthy',
            'https://alertmanager.demo.do.prometheus.io/-/healthy',
            'https://node.demo.do.prometheus.io/',
            'https://grafana.demo.do.prometheus.io/api/health',
          ],
          labels: { environment: 'prometheus.io' },
        },
      },
      thaumSites: {
        staticConfig: {
          static: [
            'https://zmc.krupa.net.pl/',
          ],
          labels: { environment: 'lancre.thaum.xyz' },
        },
      },
      ingress: {
        ingress: {
          selector: {
            matchLabels: {
              probe: 'enabled',
            },
          },
          namespaceSelector: { any: true },
        },
      },
    },
  },
  kubernetesControlPlane+: {
    kubeProxy: true,
    mixin+: {
      _config+: {
        // k3s exposes all this data under single endpoint and those can be obtained via "kubelet" Service
        kubeSchedulerSelector: 'job="kubelet"',
        kubeControllerManagerSelector: 'job="kubelet"',
        kubeApiserverSelector: 'job="kubelet"',
        kubeProxySelector: 'job="kubelet"',
        cpuThrottlingPercent: 70,
        runbookURLPattern: 'https://runbooks.thaum.xyz/runbooks/kubernetes/%s',
      },
    },
  },
  nodeExporter+: {
    version: '1.3.0',
    image: 'quay.io/prometheus/node-exporter:v1.3.0',
    filesystemMountPointsExclude:: '^/(dev|proc|sys|run/k3s/containerd/.+|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)',
    mixin+: {
      _config+: {
        runbookURLPattern: 'https://runbooks.thaum.xyz/runbooks/node/%s',
      },
    },
  },
  kubeStateMetrics+: {
    mixin+: {
      _config: {
        runbookURLPattern: 'https://runbooks.thaum.xyz/runbooks/kube-state-metrics/%s',
      },
    },
  },
  /*grafana+: {
    version: '8.2.1',
    image: 'grafana/grafana:8.2.1',
    datasources: [{
      name: 'Prometheus',
      type: 'prometheus',
      access: 'proxy',
      orgId: 1,
      isDefault: true,
      url: 'http://prometheus-k8s.monitoring.svc:9090',
    }],
    resources+: {
      limits+: {
        cpu: '400m',
      },
    },
    // TODO: Consider moving those into `grafana.config`
    env: [
      { name: 'GF_SERVER_ROOT_URL', value: 'https://grafana.uberwald.thaum.xyz' },
      { name: 'GF_AUTH_ANONYMOUS_ENABLED', value: 'false' },
      { name: 'GF_AUTH_DISABLE_LOGIN_FORM', value: 'true' },
      { name: 'GF_AUTH_SIGNOUT_REDIRECT_URL', value: 'https://auth.uberwald.thaum.xyz/oauth2?logout=true' },
      { name: 'GF_AUTH_BASIC_ENABLED', value: 'false' },
      { name: 'GF_AUTH_PROXY_AUTO_SIGN_UP', value: 'false' },
      { name: 'GF_AUTH_PROXY_ENABLED', value: 'true' },
      { name: 'GF_AUTH_PROXY_HEADER_NAME', value: 'X-Auth-Request-Email' },
      { name: 'GF_AUTH_PROXY_HEADER_PROPERTY', value: 'username' },
      { name: 'GF_AUTH_PROXY_HEADERS', value: 'Email:X-Auth-Request-Email' },
      { name: 'GF_SNAPSHOTS_EXTERNAL_ENABLED', value: 'false' },
    ],
  },*/
}
