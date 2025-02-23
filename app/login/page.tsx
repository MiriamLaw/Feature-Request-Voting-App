import { LoginForm } from "./login-form"

export default function LoginPage() {
  return (
    <main className="container max-w-lg py-6">
      <div className="mb-8 text-center">
        <h1 className="text-3xl font-bold tracking-tight">Welcome back</h1>
        <p className="text-muted-foreground">Sign in to your account to continue</p>
      </div>
      <LoginForm />
    </main>
  )
}

