"""Isolated bootstrap tests. All install/network commands are replaced by fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
STUB = r'''#!/usr/bin/env python3
import json, os, pathlib, signal, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['TEST_LOG'], 'a') as f: f.write(json.dumps([name] + args) + '\n')
if name == 'uname': print('Darwin' if args == ['-s'] else 'arm64')
elif name == 'xcode-select': sys.exit(int(os.getenv('TEST_XCODE_FAIL', '0')))
elif name == 'brew':
    if args == ['shellenv']: print('export HOMEBREW_PREFIX="' + os.environ['TEST_PREFIX'] + '"')
    elif args[:2] == ['bundle', 'check']:
        with open(os.environ['TEST_LOG'], 'a') as f: f.write(json.dumps(['skips', os.getenv('HOMEBREW_BUNDLE_CASK_SKIP', ''), os.getenv('HOMEBREW_BUNDLE_BREW_SKIP', '')]) + '\n')
        sys.exit(int(os.getenv('TEST_BUNDLE_MISSING', '0')) if not pathlib.Path(os.environ['TEST_LOG'] + '.installed').exists() else 0)
    elif args[:2] == ['bundle', 'install']:
        if os.getenv('TEST_CANCEL'): os.kill(os.getppid(), signal.SIGTERM)
        pathlib.Path(os.environ['TEST_LOG'] + '.installed').touch()
        sys.exit(int(os.getenv('TEST_BUNDLE_FAIL', '0')))
    elif args and args[0] == 'list': sys.exit(1)
elif name in ('gh', 'git'):
    sys.exit('Unexpected repository command during bootstrap')
elif name == 'ln':
    if os.getenv('TEST_LINK_CANCEL'): os.kill(os.getppid(), signal.SIGTERM)
    sys.exit(1)
elif name == 'curl':
    if os.getenv('TEST_CURL_FAIL'): sys.exit(1)
    pathlib.Path(args[args.index('-o') + 1]).write_text('#!/bin/bash\nexit 0\n')
'''


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='dotfiles-tests-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / "checkout with ' spaces"
        shutil.copytree(ROOT, self.repo, ignore=shutil.ignore_patterns('.git', '__pycache__'))
        self.home = self.base / "home with ' spaces"
        self.home.mkdir()
        self.bin = self.base / 'bin'; self.bin.mkdir()
        self.log = self.base / 'calls'
        self.prefix = self.base / 'prefix'
        nvm = self.prefix / 'opt/nvm/nvm.sh'; nvm.parent.mkdir(parents=True)
        nvm.write_text('nvm() { echo "nvm:$*" >> "$TEST_LOG"; if [[ $1 == version ]]; then echo v22.0.0; fi; }\n')
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ':/usr/bin:/bin:/usr/sbin:/sbin',
                        TEST_LOG=str(self.log), TEST_PREFIX=str(self.prefix))
        self.env.pop('NVM_DIR', None)
        self.env['DOTNET_ROOT'] = str(self.base / 'dotnet-root')
        for name in ['uname', 'xcode-select', 'brew', 'gh', 'git', 'node', 'dotnet', 'curl']:
            self.stub(name)
        # Fixtures explicitly replace the fixed production Homebrew entry point.
        install = self.repo / 'install.sh'
        install.write_text(install.read_text().replace('/opt/homebrew/bin/brew', str(self.bin / 'brew')).replace("'/Applications/", "'" + str(self.base / 'Applications') + '/'))

    def stub(self, name):
        p = self.bin / name
        p.write_text(STUB.replace('#!/usr/bin/env python3', '#!' + shutil.which('python3')))
        p.chmod(0o755)

    def run_script(self, script='install.sh', *args, expected=0):
        result = subprocess.run(['/bin/bash', str(self.repo / script), *args], env=self.env,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def calls(self):
        return self.log.read_text() if self.log.exists() else ''

    def test_default_core_only_and_tracked_config_unchanged(self):
        before = {p.name: p.read_bytes() for p in (self.repo / 'dotfiles').iterdir()}
        r = self.run_script()
        self.assertIn('links: completed', r.stdout)
        self.assertIn('extras: skipped', r.stdout)
        self.assertNotIn('Brewfile.extras', self.calls())
        self.assertNotIn('"gh"', self.calls())
        self.assertNotIn('"git"', self.calls())
        self.assertEqual(before, {p.name: p.read_bytes() for p in (self.repo / 'dotfiles').iterdir()})

    def test_links_idempotence_and_unique_backups(self):
        target = self.home / '.zshrc'; target.write_text('original')
        self.run_script('scripts/create_links.sh')
        backups = list((self.home / '.dotfiles_backup').glob('run.*'))
        self.assertEqual((backups[0] / '.zshrc').read_text(), 'original')
        self.run_script('scripts/create_links.sh')
        self.assertEqual(len(list((self.home / '.dotfiles_backup').iterdir())), 1)
        target.unlink(); target.symlink_to('/missing')
        self.run_script('scripts/create_links.sh')
        self.assertEqual(len(list((self.home / '.dotfiles_backup').iterdir())), 2)

    def test_helpers_installed_with_backups(self):
        directory = self.home / '.local/bin'; directory.mkdir(parents=True)
        (directory / 'az-context-guard').write_text('original guard')
        self.run_script('scripts/create_links.sh')
        self.assertEqual((directory / 'az-context-guard').resolve(), (self.repo / 'scripts/az-context-guard').resolve())
        self.assertEqual((directory / 'az-profile-init').resolve(), (self.repo / 'scripts/initialize_azure_profiles.sh').resolve())
        backups = list((self.home / '.dotfiles_backup').glob('run.*'))
        self.assertEqual((backups[0] / '.local/bin/az-context-guard').read_text(), 'original guard')
        self.run_script('scripts/create_links.sh')
        self.assertEqual(len(list((self.home / '.dotfiles_backup').iterdir())), 1)

    def test_failed_helper_link_restores_original(self):
        self.run_script('scripts/create_links.sh')
        guard = self.home / '.local/bin/az-context-guard'
        guard.unlink(); guard.write_text('original helper')
        self.stub('ln')
        self.run_script('scripts/create_links.sh', expected=1)
        self.assertEqual(guard.read_text(), 'original helper')

    def test_global_ignores_only_personal_artifacts(self):
        checkout = self.base / 'ignore-check'; checkout.mkdir()
        subprocess.run(['/usr/bin/git', 'init', '-q', str(checkout)], env=self.env, check=True)
        self.run_script('scripts/create_links.sh')
        ignored = ['.DS_Store', 'nested/._file', '.AppleDouble/file', '.LSOverride', '.dccache',
                   '.file.swp', '.file.swo', '.claude/settings.local.json',
                   'nested/.claude/settings.local.json', 'CLAUDE.local.md', 'nested/CLAUDE.local.md',
                   '.claude/.credentials.json', 'nested/.claude/.credentials.json',
                   '.codex/auth.json', 'nested/.codex/auth.json',
                   '.env', '.env.local', '.env.development.local', 'nested/.env', 'nested/.env.production.local']
        visible = ['app.xcodeproj/xcuserdata/user/state', 'session.xcuserstate', '.vscode/settings.json', '.idea/project.xml', '.env.example', 'bin/source.cs',
                   'app.xcodeproj/xcshareddata/xcschemes/App.xcscheme',
                   '.env.sample', '.env.template', 'nested/.env.example', 'nested/.env.sample',
                   'CLAUDE.md', 'AGENTS.md', 'AGENTS.override.md', '.claude/settings.json',
                   '.codex/config.toml', '.agents/skills/example/SKILL.md', 'public.pem', 'fixture.key']
        for path in ignored + visible:
            r = subprocess.run(['/usr/bin/git', '-C', str(checkout), 'check-ignore', '--no-index', '-q', path], env=self.env)
            self.assertEqual(r.returncode, 0 if path in ignored else 1, path)

    def test_failed_link_restores_conflict(self):
        (self.home / '.editorconfig').write_text('restore me')
        self.stub('ln')
        self.run_script('scripts/create_links.sh', expected=1)
        self.assertEqual((self.home / '.editorconfig').read_text(), 'restore me')

    def test_cancelled_link_restores_conflict(self):
        (self.home / '.editorconfig').write_text('restore me')
        self.stub('ln'); self.env['TEST_LINK_CANCEL'] = '1'
        self.run_script('scripts/create_links.sh', expected=143)
        self.assertEqual((self.home / '.editorconfig').read_text(), 'restore me')

    def test_missing_source_does_not_move_existing(self):
        (self.home / '.editorconfig').write_text('keep')
        (self.repo / 'dotfiles/.zshrc').unlink()
        self.run_script('scripts/create_links.sh', expected=1)
        self.assertFalse((self.home / '.dotfiles_backup').exists())

    def test_dry_run_has_no_calls_or_home_changes(self):
        self.run_script('install.sh', '--dry-run', '--extras')
        self.assertEqual(self.calls(), '')
        self.assertEqual(list(self.home.iterdir()), [])

    def test_arguments(self):
        for args in [('--wat',), ('--repos',), ('--parameters',), ('--parameters', 'old.json'), ('-p', 'old.json'), ('--dry-run', '--repos'), ('--links-only', '--extras'), ('unexpected',)]:
            self.run_script('install.sh', *args, expected=2)
            self.assertEqual(self.calls(), '')
            self.assertEqual(list(self.home.iterdir()), [])
        self.run_script('install.sh', '--help')

    def test_links_only_skips_prerequisites(self):
        r = self.run_script('install.sh', '--links-only')
        self.assertIn('core: skipped', r.stdout)
        self.assertNotIn('"brew"', self.calls())

    def test_prerequisite_failure_blocks_links(self):
        self.env['TEST_XCODE_FAIL'] = '1'
        r = self.run_script(expected=1)
        self.assertIn('prerequisites: failed', r.stdout)
        self.assertIn('links: blocked', r.stdout)
        self.assertFalse((self.home / '.zshrc').exists())

    def test_bundle_failure_and_cancellation(self):
        self.env.update(TEST_BUNDLE_MISSING='1', TEST_BUNDLE_FAIL='1')
        r = self.run_script(expected=1)
        self.assertIn('core: failed', r.stdout)
        self.assertIn('links: blocked', r.stdout)
        Path(str(self.log) + '.installed').unlink()
        self.env['TEST_CANCEL'] = '1'
        self.run_script(expected=143)

    def test_extras_explicit_and_existing_vscode_preserved(self):
        (self.home / 'Applications/Visual Studio Code.app').mkdir(parents=True)
        self.run_script('install.sh', '--extras')
        self.assertIn('Brewfile.extras', self.calls())
        self.assertIn('visual-studio-code', self.calls())

    def test_missing_bundle_installs_without_upgrade(self):
        self.env['TEST_BUNDLE_MISSING'] = '1'
        self.run_script()
        self.assertIn('"bundle", "install", "--no-upgrade"', self.calls())

    def test_legacy_package_types_preserved(self):
        self.stub('az'); self.stub('pwsh')
        self.run_script('install.sh', '--extras')
        self.assertIn('["skips", "azure-cli", "powershell"]', self.calls())

    def test_existing_nvm_versions_preserved(self):
        (self.bin / 'node').unlink()
        self.run_script()
        self.assertIn('nvm:version node', self.calls())
        self.assertNotIn('nvm:install', self.calls())

    def test_missing_runtimes_install_and_cleanup(self):
        (self.bin / 'node').unlink(); (self.bin / 'dotnet').unlink()
        (self.prefix / 'opt/nvm/nvm.sh').write_text('nvm() { echo "nvm:$*" >> "$TEST_LOG"; if [[ $1 == version ]]; then echo N/A; return 3; fi; }\n')
        self.run_script()
        self.assertIn('nvm:install --lts', self.calls())
        self.assertIn('dotnet-install.sh', self.calls())

    def test_custom_dotnet_root_preserved(self):
        (self.bin / 'dotnet').unlink()
        directory = Path(self.env['DOTNET_ROOT']); directory.mkdir()
        executable = directory / 'dotnet'; executable.write_text('#!/bin/bash\nexit 0\n'); executable.chmod(0o755)
        self.run_script()
        self.assertNotIn('"curl"', self.calls())

    def test_download_failure_blocks_links(self):
        (self.bin / 'dotnet').unlink(); self.env['TEST_CURL_FAIL'] = '1'
        r = self.run_script(expected=1)
        self.assertIn('runtimes: failed', r.stdout)
        self.assertIn('links: blocked', r.stdout)

    def test_missing_homebrew_requires_interactive(self):
        (self.bin / 'brew').unlink()
        self.run_script(expected=1)
        self.assertNotIn('"curl"', self.calls())

    def test_shell_integrations_and_repeated_sourcing(self):
        for present in [False, True]:
            if present:
                for name in ['.docker/completions', '.hzdb/completions']:
                    directory = self.home / name; directory.mkdir(parents=True)
                    tool = 'docker' if 'docker' in name else 'hzdb'
                    (directory / ('_' + tool)).write_text('#compdef ' + tool + '\n_arguments "*:files:_files"\n')
                for name in ['.unity/env', '.orbstack/shell/init.zsh']:
                    path = self.home / name; path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('export FIXTURE_INTEGRATION=loaded\n')
            (self.home / '.zprofile.local').write_text('export FIXTURE_PROFILE=loaded\n')
            (self.home / '.zshrc.local').write_text('export FIXTURE_RC=loaded\n')
            env = dict(self.env, HOMEBREW_PREFIX=str(self.prefix),
                       HOMEBREW_CACHE=str(self.base / 'cache'), HOMEBREW_LOGS=str(self.base / 'logs'))
            command = r'''source "$1/dotfiles/.zprofile"
source "$1/dotfiles/.zshrc"
source "$1/dotfiles/.zprofile"
source "$1/dotfiles/.zshrc"
[[ $FIXTURE_PROFILE == loaded && $FIXTURE_RC == loaded ]] || exit 1
[[ ${#path} == ${#${(u)path}} && ${#fpath} == ${#${(u)fpath}} ]] || exit 2
hooks=("${(@M)precmd_functions:#vcs_info}")
[[ ${#hooks} == 1 ]] || exit 3
if [[ $2 == True ]]; then
  [[ $FIXTURE_INTEGRATION == loaded && ${_comps[docker]} == _docker && ${_comps[hzdb]} == _hzdb ]] || exit 4
fi
compadd() { print -l -- "$@" > "$HOME/completion-values"; }
_files() { print fallback > "$HOME/completion-values"; }
dotnet() { print -l -- "$@" > "$HOME/completion-args"; print -l -- "value one" "value-two"; }
BUFFER='dotnet build "some path"'; CURSOR=12
_dotnet_zsh_complete
[[ $(cat "$HOME/completion-values") == $'--\nvalue one\nvalue-two' ]] || exit 5
[[ $(cat "$HOME/completion-args") == $'complete\n--position\n12\ndotnet build "some path"' ]] || exit 6
'''
            result = subprocess.run(['/bin/zsh', '-f', '-i', '-c', command, 'fixture', str(self.repo), str(present)],
                                    env=env, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stderr, '')

    def test_vim_undo_directory_permissions(self):
        result = subprocess.run(['/usr/bin/vim', '-u', str(self.repo / 'dotfiles/.vimrc'), '-i', 'NONE', '-n', '-es', '+q'],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.home / '.vim/undodir').stat().st_mode & 0o777, 0o700)

    def test_git_local_override(self):
        (self.home / '.gitconfig.local').write_text('[user]\n    email = fixture@example.invalid\n')
        result = subprocess.run(['/usr/bin/git', 'config', '--includes', '--file', str(self.repo / 'dotfiles/.gitconfig'), 'user.email'],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'fixture@example.invalid')


if __name__ == '__main__':
    unittest.main()
