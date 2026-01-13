#!/usr/bin/env node
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const sharp = require('sharp');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Константы конфигурации
const CONFIG = {
  logFile: '/var/log/optimization.log',
  user: 'webuser',
  group: 'webuser',
  imageQuality: 85,
  skipHours: [
    { start: 6, end: 9 },
    { start: 22, end: 23 }
  ],
  supportedExtensions: ['.jpg', '.jpeg', '.png', '.bmp', '.svg'],
  optimizationFormats: ['webp', 'avif']
};

// Класс для логирования
class Logger {
  constructor(logFile) {
    this.logFile = logFile;
  }

  log(message) {
    const logMessage = `[${new Date().toISOString()}] ${message}\n`;
    fsSync.appendFileSync(this.logFile, logMessage, 'utf8');
    console.log(message);
  }

  error(message, error) {
    this.log(`ERROR: ${message} - ${error?.message || error}`);
  }
}

// Класс для работы с файлами
class FileManager {
  static isValidFilename(filename) {
    return /^[^\0\/]+$/.test(filename);
  }

  static async changeOwnership(file, user, group) {
    try {
      await execAsync(`chown ${user}:${group} "${file}"`);
      return true;
    } catch (error) {
      throw new Error(`Failed to change ownership: ${error.message}`);
    }
  }

  static async getFiles(directory = '.') {
    try {
      return await fs.readdir(directory);
    } catch (error) {
      throw new Error(`Failed to read directory: ${error.message}`);
    }
  }

  static async fileExists(filePath) {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  static async createMarkerFile(file, user, group) {
    const markerFile = `${file}.optimised`;
    await fs.writeFile(markerFile, '');
    await this.changeOwnership(markerFile, user, group);
  }
}

// Класс для оптимизации изображений
class ImageOptimizer {
  constructor(logger, config) {
    this.logger = logger;
    this.config = config;
  }

  async optimizeToFormat(file, format) {
    const outputFile = `${file}.${format}`;

    if (await FileManager.fileExists(outputFile)) {
      this.logger.log(`${format.toUpperCase()} уже существует для ${file}`);
      return;
    }

    try {
      await sharp(file)
        .toFormat(format, { quality: this.config.imageQuality })
        .toFile(outputFile);

      this.logger.log(`Оптимизирован ${file} в ${format}`);
      await FileManager.changeOwnership(outputFile, this.config.user, this.config.group);
      this.logger.log(`Изменены права для ${outputFile}`);
    } catch (error) {
      this.logger.error(`Ошибка оптимизации ${file} в ${format}`, error);
    }
  }

  async convertBmpToJpg(file) {
    const jpgFile = file.replace('.bmp', '.jpg');
    
    try {
      await sharp(file)
        .toFormat('jpg')
        .toFile(jpgFile);
      
      this.logger.log(`Конвертирован ${file} в JPG`);
      await FileManager.changeOwnership(jpgFile, this.config.user, this.config.group);
    } catch (error) {
      this.logger.error(`Ошибка конвертации BMP в JPG`, error);
    }
  }

  async optimizeSvg(file) {
    try {
      this.logger.log(`Оптимизация SVG: ${file}`);
      await execAsync(`svgo "${file}"`);
      await FileManager.changeOwnership(file, this.config.user, this.config.group);
    } catch (error) {
      this.logger.error(`Ошибка оптимизации SVG`, error);
    }
  }

  async processFile(file) {
    const ext = path.extname(file).toLowerCase();

    if (!this.config.supportedExtensions.includes(ext) || file.endsWith('.optimised')) {
      return;
    }

    if (!FileManager.isValidFilename(file)) {
      this.logger.log(`Пропуск ${file} из-за недопустимых символов в имени`);
      return;
    }

    this.logger.log(`Обработка ${file}`);

    // BMP конвертация
    if (ext === '.bmp') {
      await this.convertBmpToJpg(file);
      return;
    }

    // SVG оптимизация
    if (ext === '.svg') {
      await this.optimizeSvg(file);
      return;
    }

    // JPEG/PNG оптимизация
    if (['.jpeg', '.jpg', '.png'].includes(ext)) {
      for (const format of this.config.optimizationFormats) {
        await this.optimizeToFormat(file, format);
      }
    }

    // Создание маркера оптимизации
    try {
      await FileManager.createMarkerFile(file, this.config.user, this.config.group);
    } catch (error) {
      this.logger.error(`Ошибка создания маркера для ${file}`, error);
    }
  }
}

// Класс для очистки файлов
class FileCleaner {
  constructor(logger) {
    this.logger = logger;
  }

  async cleanupOptimizedFiles() {
    this.logger.log('Очистка оптимизированных файлов');
    let count = 0;

    try {
      const files = await FileManager.getFiles();
      
      for (const file of files) {
        if (file.endsWith('.optimised')) {
          await fs.unlink(file);
          count++;
        }
      }

      this.logger.log(`Удалено ${count} оптимизированных файлов`);
    } catch (error) {
      this.logger.error('Ошибка при очистке файлов', error);
    }
  }
}

// Класс для управления расписанием
class ScheduleManager {
  static shouldSkipExecution(skipHours) {
    const currentHour = new Date().getHours();
    
    return skipHours.some(({ start, end }) => 
      currentHour >= start && currentHour < end
    );
  }
}

// Главная функция приложения
class Application {
  constructor(config) {
    this.config = config;
    this.logger = new Logger(config.logFile);
    this.optimizer = new ImageOptimizer(this.logger, config);
    this.cleaner = new FileCleaner(this.logger);
  }

  async run(args) {
    // Обработка команды очистки
    if (args.includes('clean')) {
      await this.cleaner.cleanupOptimizedFiles();
      return;
    }

    this.logger.log('Запуск скрипта');

    // Проверка расписания
    if (ScheduleManager.shouldSkipExecution(this.config.skipHours)) {
      this.logger.log('Пропуск выполнения из-за неоптимального времени');
      return;
    }

    // Обработка изображений
    await this.processImages();
    this.logger.log('Оптимизация завершена');
  }

  async processImages() {
    try {
      const files = await FileManager.getFiles();
      
      for (const file of files) {
        await this.optimizer.processFile(file);
      }
    } catch (error) {
      this.logger.error('Ошибка обработки изображений', error);
      throw error;
    }
  }
}

// Точка входа
(async () => {
  try {
    const app = new Application(CONFIG);
    await app.run(process.argv.slice(2));
    process.exit(0);
  } catch (error) {
    console.error('Критическая ошибка:', error);
    process.exit(1);
  }
})();
