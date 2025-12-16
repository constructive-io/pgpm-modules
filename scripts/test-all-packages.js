#!/usr/bin/env node

// TODO turn this into a pnpm command 

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ANSI color codes
const RED = '\x1b[0;31m';
const GREEN = '\x1b[0;32m';
const YELLOW = '\x1b[1;33m';
const NC = '\x1b[0m'; // No Color

// Helper functions
function dbsafename(packagePath) {
  const packageName = path.basename(packagePath);
  return `test_${packageName}`.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
}

function getProjectName(packagePath, projectRoot) {
  const planFile = path.isAbsolute(packagePath)
    ? path.join(packagePath, 'pgpm.plan')
    : path.join(projectRoot, packagePath, 'pgpm.plan');
  
  if (!fs.existsSync(planFile)) {
    return null;
  }
  
  const content = fs.readFileSync(planFile, 'utf8');
  const match = content.match(/^%project=(.+)$/m);
  return match ? match[1].trim() : null;
}

function execCommand(command, options = {}) {
  try {
    const result = execSync(command, {
      encoding: 'utf8',
      stdio: options.silent ? 'pipe' : 'inherit',
      ...options
    });
    return { success: true, output: result };
  } catch (error) {
    return { success: false, error: error.message, code: error.status || error.code };
  }
}

function commandExists(command) {
  try {
    execSync(`command -v ${command}`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function checkDockerPostgres() {
  if (!commandExists('docker')) {
    return false;
  }
  const result = execCommand('docker exec postgres psql -U postgres -c "SELECT 1;"', { silent: true });
  return result.success;
}

function checkDirectPostgres() {
  if (!commandExists('psql')) {
    return false;
  }
  const result = execCommand('psql -c "SELECT 1;"', { silent: true });
  return result.success;
}

function cleanupDb(dbname, useDocker) {
  console.log(`  Cleaning up database: ${dbname}`);
  if (useDocker) {
    execCommand(`docker exec postgres dropdb -U postgres "${dbname}"`, { silent: true });
  } else {
    execCommand(`dropdb "${dbname}"`, { silent: true });
  }
}

function createDb(dbname, useDocker) {
  if (useDocker) {
    const result = execCommand(`docker exec postgres createdb -U postgres "${dbname}"`);
    return result.success;
  } else {
    const result = execCommand(`createdb "${dbname}"`);
    return result.success;
  }
}

function findPackages(projectRoot) {
  const packages = [];
  const packagesDir = path.join(projectRoot, 'packages');
  
  if (!fs.existsSync(packagesDir)) {
    return packages;
  }
  
  function walkDir(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      
      if (entry.isDirectory()) {
        // Skip dist directories
        if (entry.name === 'dist' || fullPath.includes('/dist')) {
          continue;
        }
        walkDir(fullPath);
      } else if (entry.isFile() && entry.name === 'pgpm.plan') {
        const packagePath = path.relative(projectRoot, dir);
        packages.push(packagePath);
      }
    }
  }
  
  walkDir(packagesDir);
  return packages.sort();
}

function runPgpmCommand(command, dbname, packageName, packagePath, projectRoot) {
  const fullCommand = `pgpm ${command} --database "${dbname}" --yes --package "${packageName}"`;
  const result = execCommand(fullCommand, {
    cwd: path.join(projectRoot, packagePath)
  });
  return result.success;
}

async function testPackage(packagePath, projectRoot, useDocker) {
  const packageName = path.basename(packagePath);
  const dbname = dbsafename(packagePath);
  
  const lqlPackageName = getProjectName(packagePath, projectRoot);
  
  if (!lqlPackageName) {
    console.error(`${RED}ERROR: Could not find %project= in ${packagePath}/pgpm.plan${NC}`);
    return false;
  }
  
  console.log(`${YELLOW}Testing package: ${packageName}${NC}`);
  console.log(`  Package path: ${packagePath}`);
  console.log(`  Database name: ${dbname}`);
  
  cleanupDb(dbname, useDocker);
  
  console.log(`  Creating database: ${dbname}`);
  if (!createDb(dbname, useDocker)) {
    console.error(`${RED}FAILED: Could not create database ${dbname} for package ${packageName}${NC}`);
    return false;
  }
  
  const packageFullPath = path.join(projectRoot, packagePath);
  if (!fs.existsSync(packageFullPath)) {
    console.error(`${RED}FAILED: Could not find directory ${packageFullPath}${NC}`);
    cleanupDb(dbname, useDocker);
    return false;
  }
  
  console.log('  Running pgpm deploy...');
  if (!runPgpmCommand('deploy', dbname, lqlPackageName, packagePath, projectRoot)) {
    console.error(`${RED}FAILED: pgpm deploy failed for package ${lqlPackageName}${NC}`);
    cleanupDb(dbname, useDocker);
    return false;
  }
  
  console.log('  Running pgpm verify...');
  if (!runPgpmCommand('verify', dbname, lqlPackageName, packagePath, projectRoot)) {
    console.error(`${RED}FAILED: pgpm verify failed for package ${lqlPackageName}${NC}`);
    cleanupDb(dbname, useDocker);
    return false;
  }
  
  console.log('  Running pgpm revert...');
  if (!runPgpmCommand('revert', dbname, lqlPackageName, packagePath, projectRoot)) {
    console.error(`${RED}FAILED: pgpm revert failed for package ${lqlPackageName}${NC}`);
    cleanupDb(dbname, useDocker);
    return false;
  }
  
  console.log('  Running pgpm deploy (second time)...');
  if (!runPgpmCommand('deploy', dbname, lqlPackageName, packagePath, projectRoot)) {
    console.error(`${RED}FAILED: pgpm deploy (second time) failed for package ${lqlPackageName}${NC}`);
    cleanupDb(dbname, useDocker);
    return false;
  }
  
  cleanupDb(dbname, useDocker);
  
  console.log(`${GREEN}SUCCESS: Package ${packageName} passed all tests${NC}`);
  return true;
}

function usage() {
  console.log('Usage: node test-all-packages.js [OPTIONS]');
  console.log('');
  console.log('OPTIONS:');
  console.log('  --stop-on-fail    Stop testing immediately when a package fails (default: continue testing all packages)');
  console.log('  --help            Show this help message');
  console.log('');
}

function main() {
  const args = process.argv.slice(2);
  let stopOnFail = false;
  
  // Parse command line arguments
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--stop-on-fail') {
      stopOnFail = true;
    } else if (arg === '--help' || arg === '-h') {
      usage();
      process.exit(0);
    } else {
      console.error(`Unknown option: ${arg}`);
      usage();
      process.exit(1);
    }
  }
  
  console.log('=== PGPM Package Integration Test ===');
  console.log('Testing all packages with deploy/verify/revert/deploy cycle');
  if (stopOnFail) {
    console.log('Mode: Stop on first failure');
  } else {
    console.log('Mode: Test all packages (collect all failures)');
  }
  console.log('');
  
  if (!commandExists('pgpm')) {
    console.error(`${RED}ERROR: pgpm CLI not found. Please install pgpm globally.${NC}`);
    console.log('Run: npm install -g pgpm');
    process.exit(1);
  }
  
  const useDocker = checkDockerPostgres();
  const useDirect = !useDocker && checkDirectPostgres();
  
  if (useDocker) {
    console.log('Using Docker PostgreSQL container');
  } else if (useDirect) {
    console.log('Using direct PostgreSQL connection');
  } else {
    console.error(`${RED}ERROR: PostgreSQL not accessible.${NC}`);
    console.log('For local development: docker-compose up -d');
    console.log('For CI: ensure PostgreSQL service is running');
    process.exit(1);
  }
  
  const scriptDir = __dirname;
  const projectRoot = path.resolve(scriptDir, '..');
  process.chdir(projectRoot);
  
  console.log('Finding all PGPM packages...');
  const packages = findPackages(projectRoot);
  
  console.log(`Found ${packages.length} packages to test:`);
  for (const pkg of packages) {
    console.log(`  - ${path.basename(pkg)}`);
  }
  console.log('');
  
  const failedPackages = [];
  const successfulPackages = [];
  
  for (const packagePath of packages) {
    const success = testPackage(packagePath, projectRoot, useDocker);
    
    if (success) {
      successfulPackages.push(path.basename(packagePath));
    } else {
      failedPackages.push(path.basename(packagePath));
      
      if (stopOnFail) {
        console.log('');
        console.error(`${RED}STOPPING: Test failed for package ${path.basename(packagePath)} and --stop-on-fail was specified${NC}`);
        console.log('');
        console.log('=== TEST SUMMARY (PARTIAL) ===');
        if (successfulPackages.length > 0) {
          console.log(`${GREEN}Successful packages before failure (${successfulPackages.length}):${NC}`);
          for (const pkg of successfulPackages) {
            console.log(`  ${GREEN}✓${NC} ${pkg}`);
          }
          console.log('');
        }
        console.error(`${RED}Failed package: ${path.basename(packagePath)}${NC}`);
        console.log('');
        console.error(`${RED}OVERALL RESULT: FAILED (stopped on first failure)${NC}`);
        process.exit(1);
      }
    }
    console.log('');
  }
  
  console.log('=== TEST SUMMARY ===');
  console.log(`${GREEN}Successful packages (${successfulPackages.length}):${NC}`);
  for (const pkg of successfulPackages) {
    console.log(`  ${GREEN}✓${NC} ${pkg}`);
  }
  
  if (failedPackages.length > 0) {
    console.log('');
    console.error(`${RED}Failed packages (${failedPackages.length}):${NC}`);
    for (const pkg of failedPackages) {
      console.error(`  ${RED}✗${NC} ${pkg}`);
    }
    console.log('');
    console.error(`${RED}OVERALL RESULT: FAILED${NC}`);
    process.exit(1);
  } else {
    console.log('');
    console.log(`${GREEN}OVERALL RESULT: ALL PACKAGES PASSED${NC}`);
    process.exit(0);
  }
}

main();

