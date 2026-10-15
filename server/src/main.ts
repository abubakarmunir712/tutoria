import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // One line per request (method, path, status, time, caller), so a phone that "can't connect"
  // can be told apart from one whose requests arrive and fail.
  const http = new Logger('HTTP');
  app.use((req: Request, res: Response, next: NextFunction) => {
    const started = Date.now();
    res.on('finish', () => {
      http.log(
        `${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - started}ms from ${req.ip}`,
      );
    });
    next();
  });

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
