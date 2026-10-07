import { UserRole } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsEnum,
  IsString,
  Length,
  MinLength,
  Validate,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';
import { normalizePhone } from '../phone';

@ValidatorConstraint({ name: 'isPhoneNumber' })
class IsValidPhone implements ValidatorConstraintInterface {
  validate(value: unknown) {
    return typeof value === 'string' && normalizePhone(value) !== null;
  }
  defaultMessage() {
    return 'phone must be a valid phone number';
  }
}

export class SignupDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(2, 80)
  fullName: string;

  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail()
  email: string;

  @Validate(IsValidPhone)
  phone: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsEnum(UserRole)
  role: UserRole;
}
