import React from 'react';

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
}

export const Input = ({ id, label, ...props }: InputProps) => {
  return (
    <div>
      <label htmlFor={id} className="block text-sm font-medium text-app-foreground">
        {label}
      </label>
      <div className="mt-1">
        <input
          id={id}
          className="block w-full appearance-none rounded-md border border-app bg-app-surface px-3 py-2 text-app-foreground shadow-sm placeholder:text-app-muted focus:border-[hsl(var(--ring))] focus:outline-none focus:ring-2 focus:ring-[hsl(var(--ring))] sm:text-sm"
          {...props}
        />
      </div>
    </div>
  );
};
