<?php

declare(strict_types=1);

namespace App\Controller;

use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Throwable;

final class LabController extends AbstractController
{
    public function __construct(private readonly Connection $connection)
    {
    }

    public function info(): JsonResponse
    {
        $version = $_ENV['APP_VERSION'] ?? getenv('APP_VERSION') ?: 'dev';
        $environment = $_ENV['APP_ENV'] ?? getenv('APP_ENV') ?: 'dev';

        return $this->json([
            'application' => 'symfony-demo',
            'version' => $version,
            'environment' => $environment,
            'php' => PHP_VERSION,
        ]);
    }

    public function health(): JsonResponse
    {
        return $this->json(['status' => 'ok']);
    }

    public function ready(): JsonResponse
    {
        try {
            $this->connection->executeQuery('SELECT 1')->fetchOne();

            return $this->json([
                'status' => 'ready',
                'database' => 'ok',
            ]);
        } catch (Throwable $e) {
            return $this->json([
                'status' => 'not-ready',
                'database' => 'unavailable',
            ], 503);
        }
    }
}
