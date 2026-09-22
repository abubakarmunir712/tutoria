import { IsIn, IsString } from 'class-validator';

export class HistoryTurnDto {
  @IsIn(['user', 'assistant'])
  role: 'user' | 'assistant';

  @IsString()
  content: string;
}
