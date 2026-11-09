"""Azure helpers tested against a local fake CLI; no real Azure commands or credentials."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
AZ = r'''import json, os, pathlib, sys
args = sys.argv[1:]
config = pathlib.Path(os.environ['AZURE_CONFIG_DIR'])
with open(os.environ['TEST_AZ_LOG'], 'a') as f:
    f.write(json.dumps([str(config)] + args) + '\n')
if args[:2] == ['cloud', 'set']:
    (config / 'config').write_text(args[args.index('--name') + 1])
    if os.getenv('TEST_AZ_FAIL'): sys.exit(1)
elif args[:2] == ['cloud', 'show']:
    print((config / 'config').read_text())
elif args[:2] == ['account', 'show']:
    if os.getenv('TEST_AZ_SIGNED_OUT'): sys.exit(1)
    print(os.environ.get('TEST_AZ_TENANT', 'tenant-fixture') if args[args.index('--query') + 1] == 'tenantId' else 'subscription-fixture')
else:
    sys.exit('Unexpected Azure command; authentication must be explicit and separate')
'''


class AzureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='azure-fixture-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / 'home with spaces'; self.home.mkdir()
        self.bin = self.base / 'bin'; self.bin.mkdir()
        az = self.bin / 'az'
        az.write_text('#!' + shutil.which('python3') + '\n' + AZ); az.chmod(0o755)
        self.log = self.base / 'calls'
        self.active = self.base / 'active'; self.active.mkdir()
        (self.active / 'config').write_text('AzureCloud')
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + ':/usr/bin:/bin',
                        TEST_AZ_LOG=str(self.log), AZURE_CONFIG_DIR=str(self.active))
        self.profiles = self.home / '.config/azure-cli-profiles'

    def run_helper(self, script, *args, expected=0):
        r = subprocess.run(['/bin/bash', str(ROOT / 'scripts' / script), *args],
                           env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(r.returncode, expected, r.stdout + r.stderr)
        return r

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def init(self, *args, expected=0):
        return self.run_helper('initialize_azure_profiles.sh', *args, expected=expected)

    def guard(self, *args, expected=0):
        return self.run_helper('az-context-guard', *args, expected=expected)

    def test_all_profile_cloud_mappings_and_permissions(self):
        self.init('--all')
        expected = dict(personal='AzureCloud', government='AzureUSGovernment', order66='AzureCloud', ssc='AzureCloud', polaris='AzureCloud')
        for name, cloud in expected.items():
            p = self.profiles / name
            self.assertEqual((p / 'config').read_text(), cloud)
            self.assertEqual(p.stat().st_mode & 0o777, 0o700)
            self.assertEqual((p / 'config').stat().st_mode & 0o777, 0o600)
        self.assertTrue(all(c[1:3] == ['cloud', 'set'] for c in self.calls()))
        self.assertEqual((self.active / 'config').read_text(), 'AzureCloud')

    def test_selection_alias_and_duplicates(self):
        self.init('--profile', 'gov', '--profile', 'government')
        self.assertEqual([p.name for p in self.profiles.iterdir()], ['government'])
        self.assertEqual(len(self.calls()), 1)

    def test_existing_profile_credentials_preserved(self):
        self.init('--profile', 'personal')
        token = self.profiles / 'personal/token-fixture'; token.write_text('synthetic-local-state')
        self.log.unlink()
        self.init('--profile', 'personal')
        self.assertEqual(token.read_text(), 'synthetic-local-state')
        self.assertEqual([c[1:3] for c in self.calls()], [['cloud', 'show']])

    def test_mismatch_does_not_switch_existing_profile(self):
        p = self.profiles / 'government'; p.mkdir(parents=True)
        (p / 'config').write_text('AzureCloud')
        self.init('--profile', 'gov', expected=1)
        self.assertEqual((p / 'config').read_text(), 'AzureCloud')
        self.assertEqual([c[1:3] for c in self.calls()], [['cloud', 'show']])

    def test_failed_initialization_cleans_staging(self):
        self.env['TEST_AZ_FAIL'] = '1'
        self.init('--profile', 'government', expected=1)
        self.assertEqual(list(self.profiles.iterdir()), [])

    def test_dry_run_no_cli_or_directory_changes(self):
        (self.bin / 'az').unlink()
        self.init('--all', '--dry-run')
        self.assertFalse(self.profiles.exists())
        self.assertEqual(self.calls(), [])

    def test_invalid_arguments_no_changes(self):
        for args in [(), ('--profile',), ('--profile', 'unknown'), ('--all', '--profile', 'personal'), ('--bad',)]:
            self.init(*args, expected=2)
        self.assertFalse(self.profiles.exists())
        self.assertEqual(self.calls(), [])

    def test_missing_cli_reports_action(self):
        (self.bin / 'az').unlink()
        self.init('--all', expected=127)
        self.guard('--cloud', 'AzureCloud', expected=127)

    def test_guard_matching_cloud_tenant_and_subscription(self):
        self.guard('--cloud', 'AzureCloud', '--tenant', 'tenant-fixture', '--subscription', 'subscription-fixture')
        self.assertTrue(all(c[1:3] in [['cloud', 'show'], ['account', 'show']] for c in self.calls()))

    def test_guard_mismatches_and_signed_out_fail_closed(self):
        self.guard('--cloud', 'AzureUSGovernment', expected=1)
        self.guard('--cloud', 'AzureCloud', '--tenant', 'wrong', expected=1)
        self.guard('--cloud', 'AzureCloud', '--subscription', 'wrong', expected=1)
        self.env['TEST_AZ_SIGNED_OUT'] = '1'
        self.guard('--cloud', 'AzureCloud', expected=1)
        self.env.pop('TEST_AZ_SIGNED_OUT')
        self.env['TEST_AZ_TENANT'] = ''
        self.guard('--cloud', 'AzureCloud', expected=1)

    def test_guard_requires_well_formed_expectations(self):
        for args in [(), ('--cloud',), ('--tenant', 'fixture'), ('--cloud', '--tenant'), ('--unexpected',)]:
            self.guard(*args, expected=2)
        self.assertEqual(self.calls(), [])

    def test_symlink_profile_rejected(self):
        self.profiles.mkdir(parents=True)
        (self.profiles / 'personal').symlink_to(self.active)
        self.init('--profile', 'personal', expected=1)
        self.assertEqual(self.calls(), [])


if __name__ == '__main__':
    unittest.main()
