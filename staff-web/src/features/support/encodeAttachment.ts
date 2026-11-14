import type { AttachmentInput } from './supportTicketsApi'

export async function encodeAttachment(file: File): Promise<AttachmentInput> {
  const content = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result).split(',', 2)[1])
    reader.onerror = () => reject(new Error('File read failed'))
    reader.readAsDataURL(file)
  })
  return { name: file.name, content }
}
