import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** Lets only staff accounts through. Use after JwtAuthGuard, which identifies the caller. */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context
      .switchToHttp()
      .getRequest<{ user?: { userId: string } }>();
    const userId = req.user?.userId;
    const user = userId
      ? await this.prisma.user.findUnique({
          where: { id: userId },
          select: { isAdmin: true },
        })
      : null;
    if (!user?.isAdmin) throw new ForbiddenException('Admins only');
    return true;
  }
}
