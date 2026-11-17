# DeepSeek Harness para Nix/NixOS

Empacota o **DeepSeek Harness 0.2.2-rc.3** para Linux x86_64 diretamente do
código-fonte, com módulo NixOS para instalação declarativa.

> **Aviso:** o upstream não considera Linux um alvo de release do Desktop
> Electron. O código, porém, já tem suporte a Linux no shell e o
> `electron-builder` tem uma seção Linux. Este repositório adiciona o alvo
> `linux-x64` por meio de um patch pequeno em
> [`patches/linux-desktop.patch`](patches/linux-desktop.patch) e empacota o
> aplicativo como um projeto Electron de desenvolvimento reproduzível.

## Uso rápido

```bash
nix build
./result/bin/deepseek-harness

# sem criar o link result
nix run .
```

## Instalar no perfil do usuário

```bash
nix profile install github:matheusrosafogo/deepseekharness-nix
```

## Usar como input de flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deepseek-harness.url = "github:matheusrosafogo/deepseekharness-nix";
  };

  outputs = { self, nixpkgs, deepseek-harness, ... }: {
    nixosConfigurations.minha-maquina = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        deepseek-harness.nixosModules.default
        # ...
      ];
    };
  };
}
```

## Usar no NixOS clássico (o caso deste repositório)

Como o Multipass, o OnlyOffice e o LearnHarness, o flake pode ser carregado de
forma impura com `builtins.getFlake`. Em `/etc/nixos/packages/pkgs.nix`:

```nix
let
  var = import ../variables.nix;
  mp = builtins.getFlake "github:matheusrosafogo/multipass-nix";
  oo = builtins.getFlake "github:matheusrosafogo/onlyoffice-nix";
  lh = builtins.getFlake "github:matheusrosafogo/learnharness-nix";
  dh = builtins.getFlake "github:matheusrosafogo/deepseekharness-nix";
in
{
  imports = [
    mp.nixosModules.default
    oo.nixosModules.default
    lh.nixosModules.default
    dh.nixosModules.default   # adiciona o DeepSeek Harness ao systemPackages
  ];

  # O restante do módulo continua igual.
}
```

Também é possível instalar sem o módulo:

```nix
environment.systemPackages = [
  dh.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Para fixar um commit específico (recomendado para reprodutibilidade):

```nix
dh = builtins.getFlake "github:matheusrosafogo/deepseekharness-nix/SEU_COMMIT";
```

`builtins.getFlake` exige a feature experimental `flakes` habilitada. A
configuração atual já usa esse recurso para o Multipass.

## Como o pacote funciona

- O código-fonte vem da tag `dsh-v0.2.2-rc.3` do repositório oficial via
  `fetchFromGitHub`.
- `fetchPnpmDeps` baixa o store do pnpm de forma fixa; o build roda
  `pnpm run build:artifacts` sem rede.
- O patch de Linux adiciona `linux-x64` aos alvos de build, corrige o caminho
  do binário Electron no Linux e ajusta o launcher do CLI.
- O Electron é o **44.7.0 oficial**, baixado do release da Electron. O addon
  nativo `node-addon-require-builtin` valida a fingerprint exata do runtime e
  não aceita o Electron mais novo do nixpkgs.
- O projeto de desenvolvimento do Desktop é gerado em
  `$out/share/deepseek-harness/apps/desktop/.desktop-build/development/project`.
- O **runtime primário** é montado no build a partir de 15 assets fixos
  (`primary-runtime-assets.nix`): Node 24.21.0, CPython 3.12.14 standalone e as
  13 wheels Python travadas. O resultado fica em
  `$out/share/deepseek-harness/primary-runtime` com `runtime.json` e
  `dependencies/{node,pnpm,python}`. No primeiro uso, o app copia esse payload
  para `$DSH_HOME/dsh-runtimes/dsh-primary-runtime`.
- O wrapper `deepseek-harness` inicia o Electron com esse projeto, aponta o
  `DSH_DESKTOP_DSH_DIR`, o pnpm embutido, o `DSH_DESKTOP_PRIMARY_RUNTIME_DIR` e
  bibliotecas de runtime do Electron/Chromium.

## Limitações

- Apenas `x86_64-linux`.
- O payload Python/Office é copiado para `$DSH_HOME` no primeiro uso (cerca de
  397 MB), como no Desktop original; o Nix store permanece somente leitura.
- O smoke de Python/Office do upstream foi executado na validação do pacote,
  mas não roda dentro do sandbox do Nix porque o interpretador standalone
  depende do loader `/lib64` do sistema. O build apenas monta o payload.
- O Desktop não é um alvo de release oficial do upstream. O patch pode precisar
  de rebase em versões futuras.
- Atualizações são feitas pelo Nix, não pelo updater interno do Electron. Como
  o app roda como projeto não empacotado, o auto-update fica desativado.
- Dados, sessões e credenciais ficam em `$DSH_HOME` (padrão `~/.dsh`) e no
  diretório de dados do Electron, fora do Nix store.

## Atualizar a versão

1. Descubra a nova tag em
   [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness/tags).
2. Atualize `version` em `package.nix` e confirme que o patch ainda se aplica.
3. Atualize o `hash` do `fetchFromGitHub` (`nix flake prefetch` ou o erro do
   `nix build`).
4. Atualize o `hash` do `fetchPnpmDeps` com o valor reportado pelo build.
5. Atualize os hashes/URLs em `primary-runtime-assets.nix` se o
   `scripts/primary-runtime/lock.json` do upstream mudar.
6. Se o upstream mudar a versão do Electron exigida pelo addon, atualize
   `electronVersion` e o hash do ZIP oficial.
7. Valide com:

   ```bash
   nix build
   ./result/bin/deepseek-harness
   nix flake check
   ```

## Cache binário (opcional, recomendado)

O resultado ocupa cerca de **3,1 GB** no store (o `node_modules` do monorepo e
o payload Python/Office são grandes). Para não recompilar em cada máquina:

1. Crie um cache no [Cachix](https://app.cachix.org), por exemplo
   `matheusrosafogo-deepseek-harness`.
2. Adicione um workflow do GitHub Actions que rode `nix build` e `cachix push`.
3. Cadastre o cache em `/etc/nixos/system/substituters.nix`, como já existe
   para o Multipass e o OnlyOffice.

Sem cache, a primeira instalação baixa as dependências do pnpm e compila os
artefatos localmente.

## Licença

O DeepSeek Harness é distribuído sob a licença MIT. Consulte
[`LICENSE`](https://github.com/deepseek-ai/deepseek-harness/blob/master/LICENSE)
do upstream.
