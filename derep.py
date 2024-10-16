#!/usr/bin/env python
"""
Script to dereplicate vOTUs (viral Operational Taxonomic Units) using BLAST and ANI clustering.
"""
import os
import sys
import subprocess
import argparse
import tempfile
import shutil
import hashlib
def run_process(cmd=[], tmpdir="/tmp/", outfile=None):
    """
    The command should be a list
    Calculate md5 of the command and store it as HASH
    Run a command saving the stderr to tmpdir/HASH.err
    If outfile is specified, save stdout there; otherwise, save to tmpdir/HASH.out
    Save in tmpdir/HASH.sh the command itself
    """
    cmd_str = ' '.join(cmd)

    
    hash_object = hashlib.md5(cmd_str.encode())
    hash_str = hash_object.hexdigest()
    
    err_file = os.path.join(tmpdir, f"{hash_str}.err")
    sh_file = os.path.join(tmpdir, f"{hash_str}.sh")
    print(f"Running command [{hash_str}]:\n {cmd_str}", file=sys.stderr, flush=True)
    if outfile is None:
        out_file = os.path.join(tmpdir, f"{hash_str}.out")
    else:
        out_file = outfile
    
    with open(sh_file, 'w') as f:
        f.write(cmd_str)
    
    try:
        with open(err_file, 'w') as err, open(out_file, 'w') as out:
            subprocess.run(cmd, check=True, stderr=err, stdout=out)
    except subprocess.CalledProcessError as e:
        print("\tFAIL", file=sys.stderr, flush=True)
        print(f"Error running command: {cmd_str}")
        print(f"Error message: {e}")
        raise
    
    print("\tOK", file=sys.stderr, flush=True)


def extract_column(fromFile, colIndex, toFile, sep='\t'):
    with open(fromFile, 'r') as infile, open(toFile, 'w') as outfile:
        for line in infile:
            columns = line.strip().split(sep)
            if colIndex > 0:
                index = colIndex - 1
            else:
                index = len(columns) + colIndex
            
            if 0 <= index < len(columns):
                outfile.write(columns[index] + '\n')
            else:
                # Handle cases where the column index is out of range
                outfile.write('\n')

def check_dependency(cmd):
    """Check if a command-line tool is available."""
    try:
        versionflag = '--version'
        if cmd in ['makeblastdb', 'blastn']:
            versionflag = '-version'
        subprocess.run([cmd, versionflag], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"Error: {cmd} is not installed or not in the system PATH.")
        sys.exit(1)

def check_python_dependency(module):
    """Check if a Python module is installed."""
    try:
        __import__(module)
    except ImportError:
        print(f"Error: Python module '{module}' is not installed. Please install it using pip.")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Dereplicate vOTUs')
    parser.add_argument('-i', '--input', help='Input fasta file', required=True)
    parser.add_argument('-o', '--output', help='Output fasta file [default: %(default)s]', default="dereplicated_vOTUs.fasta")
    parser.add_argument('-t', '--threads', type=int, help="Number of threads [default: %(default)s]", default=2)
    parser.add_argument('--tmp', help="Temporary directory [default: %(default)s]", default="/tmp/")
    parser.add_argument('--min-ani', help="Minimum ANI to consider two vOTUs as the same [default: %(default)s]", default=95, type=int)
    parser.add_argument('--min_tcov', help="Minimum target coverage to consider two vOTUs as the same [default: %(default)s]", default=85, type=int)
    parser.add_argument('--keep', help="Keep the temporary directory", action='store_true')
    args = parser.parse_args()

    # Check dependencies: makeblastdb and blastn must be available
    check_dependency('makeblastdb')
    check_dependency('blastn')
    check_dependency('seqfu')

    # Check dependencies: anicalc.py and aniclust.py must be available or in the same directory as the script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    for script in ['anicalc.py', 'aniclust.py']:

        if not (os.path.exists(script) or os.path.exists(os.path.join(script_dir, script))):
            print(f"Error: {script} is not found in the current directory or in the same directory as this script.")
            sys.exit(1)

    # Check dependencies: verify if python libraries numpy and Bio.SeqIO are available
    check_python_dependency('numpy')
    check_python_dependency('Bio.SeqIO')

    # Make a random temporary directory inside args.tmp and assign it to derepTmpDir
    try:
        derepTmpDir = tempfile.mkdtemp(dir=args.tmp)
        print(f"Temporary directory: {derepTmpDir}", file=sys.stderr, flush=True)
    except OSError as e:
        print(f"Error creating temporary directory: {e}")
        sys.exit(1)

    try:
        # Run: `makeblastdb -in args.input -dbtype nucl -out $derepTmpDir/db`
        run_process(['makeblastdb', '-in', args.input, '-dbtype', 'nucl', '-out', f"{derepTmpDir}/db"], derepTmpDir)

        # Run: `blastn -query args.input -db $derepTmpDir/db -outfmt '6 std qlen slen' -max_target_seqs 10000 -out $derepTmpDir/blast.tsv -num_threads 8`
        run_process(['blastn', '-query', args.input, '-db', f"{derepTmpDir}/db", '-outfmt', '6 std qlen slen', 
                     '-max_target_seqs', '10000', '-out', f"{derepTmpDir}/blast.tsv", '-num_threads', str(args.threads)], derepTmpDir)

        # Run: `anicalc.py -i $derepTmpDir/blast.tsv -o $derepTmpDir/ani.tsv`
        run_process(['python', 'anicalc.py', '-i', f"{derepTmpDir}/blast.tsv", '-o', f"{derepTmpDir}/ani.tsv"], derepTmpDir)

        # Run: `aniclust.py --fna args.input --ani $derepTmpDir/ani.tsv --out $derepTmpDir/clusters.tsv --min_ani args.min_ani --min_tcov args.min_tcov --min_qcov 0`
        run_process(['python', 'aniclust.py', '--fna', args.input, '--ani', f"{derepTmpDir}/ani.tsv", 
                     '--out', f"{derepTmpDir}/clusters.tsv", '--min_ani', str(args.min_ani), 
                     '--min_tcov', str(args.min_tcov), '--min_qcov', '0'], derepTmpDir)


        # extract the first column of {derepTmpDir}/clusters.tsv and put it in {derepTmpDir}/list.txt
        extract_column(f"{derepTmpDir}/clusters.tsv", 1, f"{derepTmpDir}/list.txt")

        # Seqfu
        run_process(['seqfu', 'list', f"{derepTmpDir}/list.txt", args.input], derepTmpDir, outfile=f"{derepTmpDir}/votus.fasta")
        # If everything went well, copy the dereplicated vOTUs to args.output
        try:
            shutil.copy(f"{derepTmpDir}/votus.fasta", args.output)
        except Exception as e:
            print(f"Unable to copy '{derepTmpDir}/clusters.tsv' the dereplicated vOTUs to {args.output}: {e}")
        
        print(f"Dereplicated vOTUs saved to {args.output}")

    except Exception as e:
        print(f"An error occurred during the dereplication process: {e}")
        sys.exit(1)
    finally:
        # Clean up the temporary directory
        if not args.keep:
            shutil.rmtree(derepTmpDir)

if __name__ == '__main__':
    sys.exit(main())