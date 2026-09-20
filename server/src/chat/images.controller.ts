import { Controller, Get, NotFoundException, Param, Res } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Response } from 'express';

@Controller('images')
export class ImagesController {
  private readonly baseUrl: string;

  constructor(config: ConfigService) {
    this.baseUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
  }

  @Get(':filename')
  async getImage(@Param('filename') filename: string, @Res() res: Response) {
    const upstream = await fetch(`${this.baseUrl}/images/${filename}`);
    if (!upstream.ok) {
      throw new NotFoundException('Image not found');
    }
    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.setHeader('Content-Type', upstream.headers.get('content-type') ?? 'image/png');
    res.send(buffer);
  }
}
