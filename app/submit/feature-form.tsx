"use client"

import type React from "react"

import { useRouter } from "next/navigation"
import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { useToast } from "@/components/ui/use-toast"

export function FeatureForm() {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setIsLoading(true)

    const formData = new FormData(event.currentTarget)
    const response = await fetch("/api/features", {
      method: "POST",
      body: JSON.stringify({
        title: formData.get("title"),
        description: formData.get("description"),
      }),
    })

    setIsLoading(false)

    if (!response.ok) {
      return toast({
        title: "Something went wrong",
        description: "Your feature request was not submitted. Please try again.",
        variant: "destructive",
      })
    }

    toast({
      title: "Success",
      description: "Your feature request has been submitted.",
    })

    router.push("/")
    router.refresh()
  }

  return (
    <form onSubmit={onSubmit}>
      <Card>
        <CardContent className="space-y-4 pt-6">
          <div className="space-y-2">
            <Label htmlFor="title">Title</Label>
            <Input id="title" name="title" required maxLength={100} placeholder="Enter a clear, concise title" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <Textarea
              id="description"
              name="description"
              required
              maxLength={500}
              placeholder="Describe your feature request in detail"
              className="min-h-[100px]"
            />
          </div>
        </CardContent>
        <CardFooter className="justify-end space-x-2">
          <Button variant="outline" onClick={() => router.back()} disabled={isLoading}>
            Cancel
          </Button>
          <Button type="submit" disabled={isLoading}>
            Submit
          </Button>
        </CardFooter>
      </Card>
    </form>
  )
}

