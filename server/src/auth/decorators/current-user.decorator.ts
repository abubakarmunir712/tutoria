import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/** The id of the signed-in user (the access token's subject). */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const request = ctx
      .switchToHttp()
      .getRequest<{ user: { userId: string } }>();
    return request.user.userId;
  },
);
