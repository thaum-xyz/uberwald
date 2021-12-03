// TODO list:

// k3s additions:
// - kube-controller-manager-prometheus-discovery service
// - kube-scheduler-prometheus-discovery

// Things to fix in kube-prometheus
// - prometheus-pvc should be an addon
// - better `examples/` directory schema
// - addon to add 'runbook_url' annotation to every alert
// - fix SM label selector for coreDNS in kube-prometheus
// - ...

// TODO list for later
// - loading dashboards
//     from mixins:
//       - kubernetes-mixin
//       - prometheus
//       - node-exporter
//       - coredns
//       - sealed-secrets
//       - go runtime metrics (https://github.com/grafana/jsonnet-libs/tree/master/go-runtime-mixin)
//     from json:
//       - blackbox-exporter
//       - smokeping
//       - unifi
//       - nginx-controller
//       - mysql (x2)
//       - redis
//       - home dashboard

local ingress(metadata, domain, service) = {
  apiVersion: 'networking.k8s.io/v1',
  kind: 'Ingress',
  metadata: metadata {
    annotations+: {
      // Add those annotations to every ingress so oauth-proxy is used.
      'kubernetes.io/ingress.class': 'nginx',
      'cert-manager.io/cluster-issuer': 'letsencrypt-prod',
      'nginx.ingress.kubernetes.io/auth-url': 'https://signin.uberwald.thaum.xyz/oauth2/auth',
      'nginx.ingress.kubernetes.io/auth-signin': 'https://signin.uberwald.thaum.xyz/oauth2/start?rd=$scheme://$host$escaped_request_uri',
    },
  },
  spec: {
    tls: [{
      hosts: [domain],
      secretName: metadata.name + '-tls',
    }],
    rules: [{
      host: domain,
      http: {
        paths: [{
          path: '/',
          pathType: 'Prefix',
          backend: {
            service: service,
          },
        }],
      },
    }],
  },
};

local addArgs(args, name, containers) = std.map(
  function(c) if c.name == name then
    c {
      args+: args,
    }
  else c,
  containers,
);

local probe(name, namespace, labels, module, targets) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'Probe',
  metadata: {
    name: name,
    namespace: namespace,
    labels: labels,
  },
  spec: {
    prober: {
      url: 'blackbox-exporter.monitoring.svc:19115',
    },
    module: module,
    targets: targets,
  },
};

local exporter = (import 'github.com/thaum-xyz/jsonnet-libs/apps/prometheus-exporter/exporter.libsonnet');
local sealedsecret = (import 'github.com/thaum-xyz/jsonnet-libs/utils/sealedsecret.libsonnet').sealedsecret;
local antiaffinity = (import 'github.com/thaum-xyz/jsonnet-libs/utils/podantiaffinity.libsonnet');

local kp =
  (import 'github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus/main.libsonnet') +
  (import 'github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus/addons/anti-affinity.libsonnet') +
  (import 'github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus/addons/all-namespaces.libsonnet') +
  // (import 'github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus/addons/windows.libsonnet') +
  // (import 'lib/ingress.libsonnet') +
  // (import 'lib/additional-scrape-configs.libsonnet') +
  // (import './lib/k3s.libsonnet') +
  // (import './config.json') +
  {
    //
    // Configuration
    //
    // TODO: figure out how to make this a JSON/YAML file!
    values+:: (import '../config.jsonnet') +
              // TODO: Remove this when https://github.com/prometheus-operator/kube-prometheus/pull/1458 is merged
              {
                grafana+: {
                  dashboards+: (import 'github.com/grafana/grafana/grafana-mixin/mixin.libsonnet').grafanaDashboards,
                },
              },

    //
    // Objects customization
    // kube-prometheus objects first
    //

    alertmanager:: {},
    /*alertmanager+: {
      // alertmanager secret is stored as ConfigMapSecret in plain yaml file
      secret:: null,
      // TODO: move ingress and externalURL to an addon in kube-prometheus
      alertmanager+: {
        spec+: {
          externalUrl: 'https://alertmanager.' + $.values.common.baseDomain,
        },
      },
      serviceAccount+: {
        automountServiceAccountToken: false,  // TODO: move into kube-prometheus
      },
      ingress: ingress(
        $.alertmanager.service.metadata {
          name: 'alertmanager',  // FIXME: that's an artifact from previous configuration, it should be removed.
          annotations: {
            'nginx.ingress.kubernetes.io/affinity': 'cookie',
            'nginx.ingress.kubernetes.io/affinity-mode': 'persistent',
            'nginx.ingress.kubernetes.io/session-cookie-hash': 'sha1',
            'nginx.ingress.kubernetes.io/session-cookie-name': 'routing-cookie',
          },
        },
        'alertmanager.' + $.values.common.baseDomain,
        {
          name: $.alertmanager.service.metadata.name,
          port: {
            name: $.alertmanager.service.spec.ports[0].name,
          },
        },
      ),
      // TODO: move to kube-prometheus
      /*networkPolicy: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'NetworkPolicy',
        metadata: $.alertmanager.service.metadata,
        spec: {
          ingress: [{
            from: [{
              podSelector: {
                # Selector should probably be customizable
                matchExpressions: [{
                  key: "app.kubernetes.io/name",
                  operator: "In",
                  values: ["prometheus"],
                }],
              },
            }],
            ports: std.map(function(o) {
              port: o.port,
              protocol: "TCP",
            }, $.alertmanager.service.spec.ports),
          }],
          podSelector: {
            matchLabels: $.alertmanager.service.spec.selector,
          },
        },
      },
    },*/

    blackboxExporter+: {
      deployment+: {
        spec+: {
          template+: {
            spec+: {
              affinity: antiaffinity.podantiaffinity('blackbox-exporter'),
            },
          },
        },
      },
      //thaumProbe: probe('thaum-sites', $.blackboxExporter.deployment.metadata.namespace, $.blackboxExporter._config.commonLabels, 'http_2xx', $.values.blackboxExporter.probes.thaumSites),
      //ingressProbe: probe('uberwald', $.blackboxExporter.deployment.metadata.namespace, $.blackboxExporter._config.commonLabels, 'http_2xx', $.values.blackboxExporter.probes.ingress),
      // TODO: move to kube-prometheus
      /*networkPolicy: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'NetworkPolicy',
        metadata: $.blackboxExporter.service.metadata,
        spec: {
          ingress: [{
            from: [{
              podSelector: {
                # Selector should probably be customizable
                matchExpressions: [{
                  key: "app.kubernetes.io/name",
                  operator: "In",
                  values: ["prometheus"],
                }],
              },
            }],
            ports: std.map(function(o) {
              port: o.port,
              protocol: "TCP",
            }, $.blackboxExporter.service.spec.ports),
          }],
          podSelector: {
            matchLabels: $.blackboxExporter.service.spec.selector,
          },
        },
      },*/
    },

    // TODO: Remove Service and move ServiceMonitor to PodMonitor
    nodeExporter+: {
      daemonset+: {
        spec+: {
          template+: {
            // TODO: move to kube-prometheus
            metadata+: {
              annotations+: {
                'kubectl.kubernetes.io/default-container': 'node-exporter',
              },
            },
            spec+: {
              containers: std.map(
                function(c) if c.name == 'node-exporter' then
                  c {
                    args+: ['--collector.textfile.directory=/host/textfile'],
                    volumeMounts+: [{
                      mountPath: '/host/textfile',
                      mountPropagation: 'HostToContainer',
                      name: 'textfile',
                      readOnly: true,
                    }],
                  }
                else c,
                super.containers
              ),
              volumes+: [{
                hostPath: {
                  path: '/var/lib/node_exporter',
                },
                name: 'textfile',
              }],
            },
          },
        },
      },
      // TODO: move to kube-prometheus
      networkPolicy: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'NetworkPolicy',
        metadata: $.nodeExporter.service.metadata,
        spec: {
          ingress: [{
            from: [{
              podSelector: {
                // Selector should probably be customizable
                matchLabels: {
                  'app.kubernetes.io/name': 'prometheus',
                },
              },
            }],
            ports: std.map(function(o) {
              port: o.port,
              protocol: 'TCP',
            }, $.nodeExporter.service.spec.ports),
          }],
          podSelector: {
            matchLabels: $.nodeExporter.service.spec.selector,
          },
        },
      },
    },

    // Using metrics-server instead of prometheus-adapter
    prometheusAdapter:: null,

    prometheus:: {},
    /*prometheus+: {
      prometheus+: {
        spec+: {
          // TODO: move ingress and externalURL to an addon
          externalUrl: 'https://prometheus.' + $.values.common.baseDomain,
          retention: '7d',
          retentionSize: '40GB',
          storage: {
            volumeClaimTemplate: {
              metadata: {
                name: 'promdata',
              },
              spec: {
                storageClassName: 'local-path',  // For performance reasons use local disk
                accessModes: ['ReadWriteOnce'],
                resources: {
                  requests: { storage: '40Gi' },
                },
              },
            },
          },
        },
      },
      ingress: ingress(
        $.prometheus.service.metadata {
          name: 'prometheus',  // FIXME: that's an artifact from previous configuration, it should be removed.
        },
        'prometheus.' + $.values.common.baseDomain,
        {
          name: $.prometheus.service.metadata.name,
          port: {
            name: $.prometheus.service.spec.ports[0].name,
          },
        },
      ),
    },*/

    kubeStateMetrics+: {
      // TODO: move to kube-prometheus
      networkPolicy: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'NetworkPolicy',
        metadata: $.kubeStateMetrics.service.metadata,
        spec: {
          ingress: [{
            from: [{
              podSelector: {
                // Selector should probably be customizable
                matchLabels: {
                  'app.kubernetes.io/name': 'prometheus',
                },
              },
            }],
            ports: std.map(function(o) {
              port: o.port,
              protocol: 'TCP',
            }, $.kubeStateMetrics.service.spec.ports),
          }],
          podSelector: {
            matchLabels: $.kubeStateMetrics.service.spec.selector,
          },
        },
      },
    },

    kubernetesControlPlane+: {
      // k3s exposes all this data under single endpoint and those can be obtained via "kubelet" Service
      serviceMonitorApiserver:: null,
      serviceMonitorKubeControllerManager:: null,
      serviceMonitorKubeScheduler:: null,
      podMonitorKubeProxy:: null,
      serviceMonitorKubelet+: {
        spec+: {
          endpoints: std.map(
            function(e)
              if !std.objectHas(e, 'path') then
                e {
                  metricRelabelings+: [{
                    sourceLabels: ['url'],
                    targetLabel: 'url',
                    regex: '(.*)\\?.*',
                  }],
                }
              else e,
            super.endpoints,
          ),
        },
      },
    },

    grafana:: {},
    /*grafana+: {
      config+:: {},
      dashboardSources+:: {},
      //dashboardDefinitions:: {},
      deployment+: {
        spec+: {
          template+: {
            metadata+: {
              // Unwanted when using persistance
              annotations:: {},
            },
            spec+: {
              containers: std.map(
                function(c) c {
                  volumeMounts: [
                    {
                      mountPath: '/var/lib/grafana',
                      name: 'grafana-storage',
                    },
                    {
                      mountPath: '/etc/grafana/provisioning/datasources',
                      name: 'grafana-datasources',
                    },
                  ],
                }, super.containers,
              ),
              // TODO: figure out why this was needed. Longhorn issues?
              securityContext: {
                runAsNonRoot: true,
                runAsUser: 472,
              },
              // Enable storage persistence
              volumes: [
                {
                  name: 'grafana-storage',
                  persistentVolumeClaim: {
                    claimName: 'grafana-data',
                  },
                },
                {
                  name: 'grafana-datasources',
                  secret: {
                    secretName: 'grafana-datasources',
                  },
                },
              ],
            },
          },
        },
      },

      // TODO: Remove PrometheusRule object when https://github.com/prometheus-operator/kube-prometheus/pull/1458 is merged
      prometheusRule: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: $.grafana.deployment.metadata {
          name: $.grafana.deployment.metadata.name + '-rules',
        },
        spec: {
          local r = std.parseYaml(importstr 'github.com/grafana/grafana/grafana-mixin/rules/rules.yaml').groups,
          local a = std.parseYaml(importstr 'github.com/grafana/grafana/grafana-mixin/alerts/alerts.yaml').groups,
          groups: a + r,
        },
      },

      pvc: {
        kind: 'PersistentVolumeClaim',
        apiVersion: 'v1',
        metadata: {
          name: 'grafana-data',
          namespace: $.grafana.deployment.metadata.namespace,
        },
        spec: {
          storageClassName: 'managed-nfs-storage',
          accessModes: ['ReadWriteMany'],
          resources: {
            requests: {
              storage: '60Mi',
            },
          },
        },
      },

      ingress: ingress(
        $.grafana.service.metadata {
          annotations: {
            'nginx.ingress.kubernetes.io/auth-response-headers': 'X-Auth-Request-Email',
          },
        },
        'grafana.' + $.values.common.baseDomain,
        {
          name: $.grafana.service.metadata.name,
          port: {
            name: $.grafana.service.spec.ports[0].name,
          },
        },
      ),
    },*/

    //
    // Custom components
    //

  } +
  // kube-linter annotations need to be added after all objects are created
  //(import 'lib/kube-linter.libsonnet') +
  {};

//
// Manifestation
//
{
  ['0setup/' + resource + '.yaml']: std.manifestYamlDoc(kp[component][resource])
  for component in std.objectFields(kp)
  for resource in std.filter(
    function(resource)
      kp[component][resource].kind == 'CustomResourceDefinition' || kp[component][resource].kind == 'Namespace', std.objectFields(kp[component])
  )
} + {
  [component + '/' + resource + '.yaml']: std.manifestYamlDoc(kp[component][resource])
  for component in std.objectFields(kp)
  for resource in std.filter(
    function(resource)
      kp[component][resource].kind != 'CustomResourceDefinition' && kp[component][resource].kind != 'Namespace', std.objectFields(kp[component])
  )
}