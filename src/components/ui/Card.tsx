import { cva, type VariantProps } from 'class-variance-authority';

const card = cva('rounded-lg border bg-white text-gray-900 shadow-sm', {
  variants: {},
  defaultVariants: {},
});

export interface CardProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof card> {}

export const Card = ({ className, ...props }: CardProps) => {
  return <div className={card({ className })} {...props} />;
};
