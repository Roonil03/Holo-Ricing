import hashlib, json, os, pathlib, subprocess, sys, tempfile
component = sys.argv[1]
def snapshot(root):
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
with tempfile.TemporaryDirectory(prefix='ina-component-') as temp:
 root=pathlib.Path(temp); home=root/'home'; home.mkdir()
 before={}
 opts=[]
 if component == 'vscode':
  target=home/'.config/Code/User/settings.json'; target.parent.mkdir(parents=True)
  target.write_text('{\n // keep my comment\n "editor.fontSize": 17,\n "workbench.colorCustomizations": {"custom.keep": "yes"},\n}\n')
  opts=['--settings',str(target)]
 if component == 'firefox':
  target=home/'.mozilla/firefox/profile with spaces'; target.mkdir(parents=True)
  (target/'user.js').write_text('// keep my preference\nuser_pref("test.original", true);\n')
  opts=['--profile',str(target),'--user-chrome']
 if component in ('wallpaper','lockscreen'):
  images=[]
  for i in range(4):
   p=home/f'approved image {i}.png'
   # Test fixtures contain only an image header. No image assets enter the repository.
   p.write_bytes(b'\x89PNG\r\n\x1a\n'+bytes([i])); images.append(str(p))
  opts=['--approved','--image',images[0]]
  if component=='lockscreen': opts+=['--images',*images[1:]]
 if component=='widgets': opts=['--widgets','clock','calendar','system']
 if component=='install': opts=['--components','icons','nemo']
 if component=='grub': opts=['--allow-boot-change']
 before=snapshot(home)
 cmd=['bash',f'Ina/scripts/{component}.sh','--test-root',temp,*opts]
 def run(extra, expected=0):
  result=subprocess.run(cmd+extra,capture_output=True,text=True)
  if result.returncode != expected: raise AssertionError(result.stdout+result.stderr)
  return result
 baseline=snapshot(root)
 run(['--dry-run'])
 assert snapshot(root)==baseline,'dry run changed files'
 result=run(['--apply']+(['--','bash','-c','exit 0'] if component=='gaming-mode' else []))
 first=snapshot(root)
 run(['--apply']+(['--','bash','-c','exit 0'] if component=='gaming-mode' else []))
 assert snapshot(root)==first,'second application changed files'
 for restored in (['icons','nemo'] if component=='install' else [component]):
  for _ in range(2):
   result=subprocess.run(['bash','Ina/scripts/restore.sh','--test-root',temp,'--component',restored,'--apply'],capture_output=True,text=True)
   assert result.returncode==0,result.stdout+result.stderr
 assert snapshot(home)==before,'rollback changed original user files'
 values=json.loads((root/'settings.json').read_text()) if (root/'settings.json').exists() else {}
 manifest=root/'state/backups'/('icons' if component=='install' else component)/'manifest.json'
 if manifest.exists():
  data=json.loads(manifest.read_text())
  for identity,entry in data['settings'].items(): assert values[identity]==entry['original'],identity
 print(component+': dry-run, apply, repeat, rollback, repeat rollback passed')
