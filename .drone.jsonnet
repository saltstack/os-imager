local common_distros = [
  // Multiprier is way to throttle API requests in order not to hit the limits
  { display_name: 'Arch', name: 'arch', version: '2019-01-09', multiplier: 1 },
  { display_name: 'CentOS 6', name: 'centos', version: '6', multiplier: 2 },
  { display_name: 'CentOS 7', name: 'centos', version: '7', multiplier: 3 },
  { display_name: 'Debian 8', name: 'debian', version: '8', multiplier: 4 },
  { display_name: 'Debian 9', name: 'debian', version: '9', multiplier: 5 },
  { display_name: 'Fedora 28', name: 'fedora', version: '28', multiplier: 6 },
  { display_name: 'Fedora 29', name: 'fedora', version: '29', multiplier: 7 },
  { display_name: 'Opensuse 15', name: 'opensuse', version: '15', multiplier: 8 },
  { display_name: 'Opensuse 42.3', name: 'opensuse', version: '42.3', multiplier: 9 },
  { display_name: 'Ubuntu 1404', name: 'ubuntu', version: '1404', multiplier: 10 },
  { display_name: 'Ubuntu 1604', name: 'ubuntu', version: '1604', multiplier: 11 },
  { display_name: 'Ubuntu 1804', name: 'ubuntu', version: '1804', multiplier: 12 },
];

local aws_distros = [
  // Windows builds have a 0 multiplier because we want them to start first and they are few enough not to hit API limits
  //  { display_name: 'Windows 2008r2', name: 'windows', version: '2008r2', multiplier: 0 },
  { display_name: 'Windows 2012r2', name: 'windows', version: '2012r2', multiplier: 0 },
  { display_name: 'Windows 2016', name: 'windows', version: '2016', multiplier: 0 },
  { display_name: 'Windows 2019', name: 'windows', version: '2019', multiplier: 0 },
];

local BuildTrigger(kind) = {
  ref: [
    std.format('refs/tags/%s-base-v1.*', [std.asciiLower(kind)]),
  ],
  event: [
    'tag',
  ],
};

local StagingBuildTrigger() = {
  event: [
    'push',
    'pull_request',
  ],
  branch: [
    'master',
  ],
};

local Lint(kind) = {

  local build_distros = if std.asciiLower(kind) == 'aws' then common_distros + aws_distros else common_distros,

  kind: 'pipeline',
  name: std.format('Lint %s', [kind]),
  steps: [
    {
      name: distro.display_name,
      image: 'hashicorp/packer',
      commands: [
        'apk --no-cache add --update py-pip',
        'pip install invoke',
        std.format('inv build-%s --validate --distro=%s --distro-version=%s', [
          std.asciiLower(kind),
          distro.name,
          distro.version,
        ]),
      ],
      depends_on: [
        'clone',
      ],
    }
    for distro in build_distros
  ],
};

local Build(kind, distro, staging) = {
  kind: 'pipeline',
  name: std.format('%s %s%s', [kind, distro.display_name, if staging then ' (Staging)' else '']),
  steps: [
    {
      name: 'throttle-build',
      image: 'alpine',
      commands: [
        std.format(
          "sh -c 'echo Sleeping %(offset)s seconds; sleep %(offset)s'",
          { offset: 7 * distro.multiplier }
        ),
      ],
    },
  ] + [
    {
      name: 'base-image',
      image: 'hashicorp/packer',
      environment: (
        if std.asciiLower(kind) == 'docker' then {
          DOCKER_HOST: 'tcp://docker:2375',
          DOCKER_USERNAME: {
            from_secret: 'docker_username',
          },
          DOCKER_PASSWORD: {
            from_secret: 'docker_password',
          },
        } else {
          AWS_DEFAULT_REGION: 'us-west-2',
          AWS_ACCESS_KEY_ID: {
            from_secret: 'username',
          },
          AWS_SECRET_ACCESS_KEY: {
            from_secret: 'password',
          },
        }
      ),
      commands: [
        'apk --no-cache add --update py-pip make curl grep gawk sed',
      ] + (
        if std.asciiLower(kind) == 'docker' then [
          'apk --no-cache add --update docker',
        ] else []
      ) + [
        'pip install invoke',
        std.format('inv build-%s%s --distro=%s --distro-version=%s', [
          std.asciiLower(kind),
          if staging then ' --staging' else '',
          distro.name,
          distro.version,
        ]),
      ],
      depends_on: [
        'throttle-build',
      ],
    },
  ],
  trigger: if staging then StagingBuildTrigger() else BuildTrigger(kind),
  depends_on: [
    std.format('Lint %s', [kind]),
  ],
  services: (
    if std.asciiLower(kind) == 'docker' then [
      {
        name: 'docker',
        image: 'docker:edge-dind',
        privileged: true,
        environment: {},
        command: [
          '--storage-driver=overlay2',
        ],
      },
    ] else []
  ),
};


local Secret() = {
  kind: 'secret',
  data: {
    username: 'I0tTPep0OuH_qwx5v5-cr4gONWEDbccbJ4yShpI369wV5WYYRuq1Gckx40A6_OK_ypQ4AfAiDjEsC2U=',
    password: 'ood6DhiPeWBKZfSOqhsq-iJPmkfnrbdIonynU7Hdd_gTk4eeii_l4cbit9O3s5P-iX3CWa_v6RwKtKz9vQd6V0MuphwGxRAcSC1z4O3R0g==',
    docker_username: 'docker username',
    docker_password: 'docker password',
  },
};

[
  Lint(kind)
  for kind in ['AWS', 'Docker']
] + [
  Build('AWS', distro, false)
  for distro in common_distros + aws_distros
] + [
  Build('Docker', distro, false)
  for distro in common_distros
] + [
  Build('AWS', distro, true)
  for distro in common_distros + aws_distros
] + [
  Build('Docker', distro, true)
  for distro in common_distros
] + [
  Secret(),
]
