// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

protocol AccountsCoordinatorDelegate: class {
    func didCancel(in coordinator: AccountsCoordinator)
    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator)
}

class AccountsCoordinator: Coordinator {

    let navigationController: UINavigationController
    let keystore: Keystore
    let session: WalletSession
    let balanceCoordinator: TokensBalanceService
    var coordinators: [Coordinator] = []

    lazy var accountsViewController: AccountsViewController = {
        let controller = AccountsViewController(keystore: keystore, balanceCoordinator: balanceCoordinator)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss))
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        controller.allowsAccountDeletion = true
        controller.delegate = self
        return controller
    }()

    weak var delegate: AccountsCoordinatorDelegate?

    init(
        navigationController: UINavigationController,
        keystore: Keystore,
        session: WalletSession,
        balanceCoordinator: TokensBalanceService
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.keystore = keystore
        self.session = session
        self.balanceCoordinator = balanceCoordinator
    }

    func start() {
        navigationController.pushViewController(accountsViewController, animated: false)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }

    @objc func add() {
        showCreateWallet()
    }

    func showCreateWallet() {
        let coordinator = WalletCoordinator(keystore: keystore)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(.welcome)
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
    }

    func showInfoSheet(for account: Wallet, sender: UIView) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.popoverPresentationController?.sourceView = sender
        controller.popoverPresentationController?.sourceRect = sender.centerRect

        switch account.type {
        case .privateKey(let account):
            let actionTitle = NSLocalizedString("wallets.backup.alertSheet.title", value: "Backup Keystore", comment: "The title of the backup button in the wallet's action sheet")
            let backupKeystoreAction = UIAlertAction(title: actionTitle, style: .default) { [unowned self] _ in
                let coordinator = BackupCoordinator(
                    navigationController: self.navigationController,
                    keystore: self.keystore,
                    account: account
                )
                coordinator.delegate = self
                coordinator.start()
                self.addCoordinator(coordinator)
            }
            let exportTitle = NSLocalizedString("wallets.export.alertSheet.title", value: "Export Private Key", comment: "The title of the export button in the wallet's action sheet")
            let exportPrivateKeyAction = UIAlertAction(title: exportTitle, style: .default) { [unowned self] _ in

                let coordinator = ExportPrivateKeyCoordinator(
                    navigationController: self.navigationController,
                    keystore: self.keystore,
                    account: account
                )
                coordinator.delegate = self
                coordinator.start()
                self.addCoordinator(coordinator)
            }
            controller.addAction(backupKeystoreAction)
            controller.addAction(exportPrivateKeyAction)
        case .hd, .address:
            break
        }

        let copyAction = UIAlertAction(
            title: NSLocalizedString("Copy Address", value: "Copy Address", comment: ""),
            style: .default
        ) { _ in
            UIPasteboard.general.string = account.address.description
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", value: "Cancel", comment: ""), style: .cancel) { _ in }

        controller.addAction(copyAction)
        controller.addAction(cancelAction)
        navigationController.present(controller, animated: true, completion: nil)
    }
}

extension AccountsCoordinator: AccountsViewControllerDelegate {
    func didSelectAccount(account: Wallet, in viewController: AccountsViewController) {
        delegate?.didSelectAccount(account: account, in: self)
    }

    func didDeleteAccount(account: Wallet, in viewController: AccountsViewController) {
        delegate?.didDeleteAccount(account: account, in: self)
    }

    func didSelectInfoForAccount(account: Wallet, sender: UIView, in viewController: AccountsViewController) {
        showInfoSheet(for: account, sender: sender)
    }
}

extension AccountsCoordinator: WalletCoordinatorDelegate {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        delegate?.didAddAccount(account: account, in: self)
        accountsViewController.fetch()
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didFail(with error: Error, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }
}

extension AccountsCoordinator: BackupCoordinatorDelegate {
    func didCancel(coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(wallet: Wallet, in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension AccountsCoordinator: ExportPrivateKeyCoordinatorDelegate {
    func didCancel(in coordinator: ExportPrivateKeyCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }
}
