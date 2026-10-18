"""Offline constraint/wiring checks. PASS is not measured electrical safety."""
from pathlib import Path
import copy,hashlib,json,re,unittest

ROOT=Path(__file__).resolve().parents[2]
REF=ROOT/'ipcore/ddr3_100h/pnr/ddr_test.fdc'
HERE=Path(__file__).resolve().parent

def read_fdc(text):
    result={}
    for port,key,value in re.findall(r'define_attribute\s+\{p:([^}]+)\}\s+\{([^}]+)\}\s+\{([^}]+)\}',text):
        result.setdefault(port,{})[key]=value.upper()
    return result

def check_ddr(ports,reference):
    errors=[];used={}
    for name,ref in reference.items():
        if not name.startswith('mem_'):continue
        row=ports.get(name,{})
        if row.get('PAP_IO_LOC')!=ref.get('PAP_IO_LOC'):errors.append(name+': pin mismatch')
        if row.get('PAP_IO_VCCIO')!='1.5':errors.append(name+': VCCIO must be 1.5')
        if row.get('PAP_IO_STANDARD')!=ref.get('PAP_IO_STANDARD'):errors.append(name+': standard mismatch')
    for name,row in ports.items():
        pin=row.get('PAP_IO_LOC')
        if pin in used:errors.append(name+': duplicate pin '+pin)
        if pin:used[pin]=name
    return errors

def check_camera(rows,j8,occupied):
    errors=[];used=set()
    for r in rows:
        pin=r['j8'];src=r['j7'];kind=r['kind']
        if pin in used:errors.append('duplicate J8 '+str(pin))
        used.add(pin)
        dest=j8.get(str(pin))
        if dest is None:errors.append('unknown J8 '+str(pin));continue
        if kind=='3V3' and dest!='3V3':errors.append('camera 3V3 on non-3V3 pin')
        if kind=='GND' and dest!='GND':errors.append('camera ground on non-ground pin')
        if kind=='signal':
            if dest in ('3V3','5V','GND'):errors.append('signal on power/ground')
            if pin in (7,35,36):errors.append('shared RS485/UART pin')
            if r['ball']!=dest:errors.append('wrong FPGA ball')
            if dest in occupied:errors.append('DDR/control collision '+dest)
            if r['signal']=='PCLK' and pin not in (8,10,27,29):errors.append('PCLK not on listed GMCLK pin')
    if {r['j7'] for r in rows}!=set(range(1,21)):errors.append('J7 pin coverage')
    return errors

def check_clock_policy(m):
    if m.get('adapter_oscillator_populated'):
        x=next(r for r in m['connections'] if r['signal']=='XCLK')
        if x.get('connect',True) or m.get('fpga_drive_xclk')!=0:
            return ['populated adapter oscillator conflicts with FPGA XCLK wiring/drive']
    return []

class GuardTests(unittest.TestCase):
    def setUp(self):
        self.ref=read_fdc(REF.read_text());self.ddr=read_fdc((ROOT/'checks/ddr_bist/ddr_bist.fdc').read_text())
        self.m=json.loads((HERE/'camera_j8_draft.json').read_text())
    def test_good_ddr(self):self.assertEqual(check_ddr(self.ddr,self.ref),[])
    def test_wrong_ddr_voltage(self):
        self.ddr['mem_dq[0]']['PAP_IO_VCCIO']='3.3';self.assertTrue(check_ddr(self.ddr,self.ref))
    def test_wrong_ddr_pin(self):
        self.ddr['mem_dq[0]']['PAP_IO_LOC']='AB21';self.assertTrue(check_ddr(self.ddr,self.ref))
    def test_wrong_ddr_standard(self):
        self.ddr['mem_dqs[0]']['PAP_IO_STANDARD']='LVCMOS33';self.assertTrue(check_ddr(self.ddr,self.ref))
    def test_good_camera(self):self.assertEqual(check_camera(self.m['connections'],self.m['j8'],set()),[])
    def test_straight_cable_5v(self):
        self.m['connections'][1]['j8']=2;self.assertTrue(check_camera(self.m['connections'],self.m['j8'],set()))
    def test_signal_on_supply(self):
        self.m['connections'][2]['j8']=40;self.assertTrue(check_camera(self.m['connections'],self.m['j8'],set()))
    def test_clock_wrong_pin(self):
        r=next(x for x in self.m['connections'] if x['signal']=='PCLK');r['j8']=11;r['ball']='AA19'
        self.assertTrue(check_camera(self.m['connections'],self.m['j8'],set()))
    def test_duplicate_ball(self):
        self.ddr['rst_board']['PAP_IO_LOC']='P6';self.assertTrue(check_ddr(self.ddr,self.ref))
    def test_populated_clock_policy(self):self.assertEqual(check_clock_policy(self.m),[])
    def test_clock_contention(self):
        self.m['fpga_drive_xclk']=1;self.assertTrue(check_clock_policy(self.m))
    def test_collision(self):self.assertTrue(check_camera(self.m['connections'],self.m['j8'],{'Y18'}))

def main():
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(GuardTests)
    result=unittest.TextTestRunner(verbosity=1).run(suite)
    if not result.wasSuccessful():raise SystemExit(1)
    fdc=ROOT/'checks/ddr_bist/ddr_bist.fdc';ref=read_fdc(REF.read_text());data=read_fdc(fdc.read_text())
    errors=check_ddr(data,ref);m=json.loads((HERE/'camera_j8_draft.json').read_text())
    errors+=check_camera(m['connections'],m['j8'],{v.get('PAP_IO_LOC') for v in data.values()})
    errors+=check_clock_policy(m)
    assert not errors,errors
    report={'digital_checks':'PASS','guard_tests':result.testsRun,'ddr_signals':sum(k.startswith('mem_') for k in ref),
      'camera_connector':'J8','camera_wiring':'DRAFT_NOT_APPROVED_FOR_POWER',
      'physical_measurements':'NONE','open_items':['Vendor schematics reviewed: no full 3.3V/2.8V signal translator; actual revision and module FPC identity not fully verified',
      'Adapter schematic DOVDD 2.8V and optional SCCB pull-ups to 2.8V; 3.3V host tolerance and populated parts require confirmation',
      'V4: manual oscillator supply 1.8V; current receiver VCCIO 1.5V / LVCMOS15; tolerance not established',
      'SCBV unset; configuration-bank mode/voltage rules need confirmation'],
      'inputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [fdc,REF,HERE/'camera_j8_draft.json']}}
    (HERE/'audit_result.json').write_text(json.dumps(report,indent=2))
    print('PASS 49 DDR signal constraints and J7/J8 mapping guards; electrical approval remains OPEN')

if __name__=='__main__':main()
