#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { exec } = require('child_process');
const { promisify } = require('util');

// Promisify exec for asynchronous execution
const execAsync = promisify(exec);

const logFile = "/var/log/optimization.log";
const currentHour = new Date().getHours();

const iUser = 'webuser';
const iGroup = 'webuser';

// Helper function for logging
function log(message) {
  fs.appendFileSync(logFile, `${message}\n`, 'utf8');
  console.log(`${message}`);
}

// Function to clean up optimized files
async function cleanupOptimizedFiles() {
  log("Cleaning up optimized files");
  let count = 0;
  const files = fs.readdirSync('.');
  for (const file of files) {
    if (file.endsWith('.optimised')) {
      fs.unlinkSync(file);
      count++;
    }
  }
  log(`Removed ${count} optimized files`);
}

// Handle parameters
if (process.argv.includes('clean')) {
  cleanupOptimizedFiles();
  process.exit(0);
}

log(`Script started at ${new Date().toLocaleString()}`);

// Skip execution for certain hours
if ((currentHour >= 6 && currentHour < 9) || (currentHour >= 22 && currentHour < 23)) {
  log("Skipping script execution due to non-optimal hours");
  process.exit(0);
}

// Check for valid filenames
const isValidFilename = (filename) => /^[^\0\/]+$/.test(filename);

// Optimize images using sharp
async function optimizeImage(file, format) {
  const outputFile = `${file}.${format}`;
  if (fs.existsSync(outputFile)) {
    log(`${format.toUpperCase()} already exists for ${file}`);
    return;
  }

  try {
    await sharp(file)
      .toFormat(format, { quality: 85 })
      .toFile(outputFile);

    log(`Optimized ${file} to ${format}`);

    // Change ownership asynchronously
    await execAsync(`chown ${iUser}:${iGroup} ${outputFile}`);
    log(`Changed ownership of ${outputFile} to ${iUser}:${iGroup}`);
  } catch (error) {
    log(`Error optimizing ${file} to ${format}: ${error}`);
  }
}

// Main function to process images
async function processImages() {
  const files = fs.readdirSync('.');

  for (const file of files) {
    const ext = path.extname(file).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.bmp', '.svg'].includes(ext) && !file.endsWith('.optimised')) {
      if (!isValidFilename(file)) {
        log(`Skipping ${file} due to invalid characters in filename`);
        continue;
      }

      log(`Processing ${file}`);

      // Handle BMP files separately
      if (ext === '.bmp') {
        const jpgFile = file.replace('.bmp', '.jpg');
        try {
          await sharp(file)
            .toFormat('jpg')
            .toFile(jpgFile);
          
          log(`Converted ${file} to JPG`);
          await execAsync(`chown ${iUser}:${iGroup} ${jpgFile}`);
        } catch (err) {
          log(`Error converting BMP to JPG: ${err}`);
        }
        continue;
      }

      // Optimize SVG files
      if (ext === '.svg') {
        try {
          log(`Optimizing SVG: ${file}`);
          await execAsync(`svgo ${file}`);
          await execAsync(`chown ${iUser}:${iGroup} ${file}`);
        } catch (err) {
          log(`Error optimizing SVG: ${err}`);
        }
        continue;
      }

      // Optimize JPEG, PNG to WebP and AVIF
      if (ext === '.jpeg' || ext === '.jpg' || ext === '.png') {
        await optimizeImage(file, 'webp');
        await optimizeImage(file, 'avif');
      }

      // Mark file as optimized
      try {
        fs.writeFileSync(`${file}.optimised`, '');
        await execAsync(`chown ${iUser}:${iGroup} ${file}.optimised`);
      } catch (err) {
        log(`Error marking ${file} as optimized: ${err}`);
      }
    }
  }
}

// Perform image optimization
(async () => {
  await processImages();
  log(`Optimization completed at ${new Date().toLocaleString()}`);
})();
