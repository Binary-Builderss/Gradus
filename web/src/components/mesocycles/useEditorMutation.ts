import { useMutation, useQueryClient } from '@tanstack/react-query'

/**
 * Mutazione dell'editor: tutte condividono la chiave ['editor'], così la barra di stato le segue,
 * e a fine corsa (anche in errore) ricaricano le query indicate.
 */
export function useEditorMutation<V>(fn: (v: V) => Promise<unknown>, invalidate: string[][]) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationKey: ['editor'],
    mutationFn: fn,
    onSettled: () => Promise.all(invalidate.map((queryKey) => queryClient.invalidateQueries({ queryKey }))),
  })
}
