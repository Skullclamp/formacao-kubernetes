<?php

declare(strict_types=1);

namespace App\Controller;

use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Throwable;

/**
 * Controlador pedagógico usado para expor três endpoints operacionais:
 * /info, /health e /ready.
 */
final class LabController extends AbstractController
{
    /**
     * Injeta a ligação Doctrine DBAL.
     * É usada apenas no endpoint /ready para confirmar a disponibilidade da BD.
     */
    public function __construct(private readonly Connection $connection)
    {
    }

    /**
     * /info — devolve metadata útil para confirmar que versão e ambiente
     * estão efetivamente em execução depois de um deploy ou update.
     */
    public function info(): JsonResponse
    {
        // Lê primeiro as variáveis disponibilizadas pelo Symfony e usa getenv()
        // como fallback. Se não existirem, assume "dev".
        $version = $_ENV['APP_VERSION'] ?? getenv('APP_VERSION') ?: 'dev';
        $environment = $_ENV['APP_ENV'] ?? getenv('APP_ENV') ?: 'dev';

        // Resposta JSON simples para validação manual ou automática.
        return $this->json([
            'application' => 'symfony-demo',
            'version' => $version,
            'environment' => $environment,
            'php' => PHP_VERSION,
        ]);
    }

    /**
     * /health — confirma apenas que a aplicação está viva e consegue responder HTTP.
     * Não testa dependências externas como PostgreSQL.
     */
    public function health(): JsonResponse
    {
        return $this->json(['status' => 'ok']);
    }

    /**
     * /ready — valida se a aplicação está pronta para trabalhar com a BD.
     * Esta distinção permite demonstrar health != readiness.
     */
    public function ready(): JsonResponse
    {
        try {
            // SELECT 1 é uma consulta mínima: confirma que existe uma ligação
            // funcional ao PostgreSQL sem depender de dados da aplicação.
            $this->connection->executeQuery('SELECT 1')->fetchOne();

            return $this->json([
                'status' => 'ready',
                'database' => 'ok',
            ]);
        } catch (Throwable $e) {
            // Se a base de dados estiver indisponível, a aplicação continua viva,
            // mas /ready responde HTTP 503 para indicar que não está pronta.
            return $this->json([
                'status' => 'not-ready',
                'database' => 'unavailable',
            ], 503);
        }
    }
}
