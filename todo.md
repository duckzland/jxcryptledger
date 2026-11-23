# Todo List

- Update export and import dialog to show progress loading and only close until the action completed
- Update the txs batch form to show progress bar when doing the action and only close when the action completed
- Add more tests for complete features set
- Fix slow finalized when fired with many txs at batch txs but not at per card txs
- create batch txs operations function and utilize ipc putAll for actions, return the failed tx and update the batch form to match it
