import { PendingFeaturePanel } from '../shared/PendingFeaturePanel'

export function SignInPage() {
  return <PendingFeaturePanel description="The current API does not yet define a secure browser-session contract. Existing opaque bearer credentials remain for the current clients." eyebrow="STAFF AUTHENTICATION" title="Sign-in is not connected" />
}
