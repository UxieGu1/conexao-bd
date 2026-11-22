-- ============================================================================
-- UNIVERSIDADE FEDERAL DO CEARÁ (UFC) - CAMPUS QUIXADÁ
-- DISCIPLINA: Fundamentos de Bancos de Dados (Etapa 2 - Projeto e Implementação)
-- PROJETO: Sistema de Acompanhamento de Obras Públicas (Equipe T01)
-- SCRIPT 02: Povoamento inicial das tabelas (executar após 01_create_estruturas.sql)
-- ============================================================================

-- 1. Secretarias (RF11)
INSERT INTO secretaria (nome_oficial, sigla) VALUES
('Secretaria de Infraestrutura e Desenvolvimento Urbano', 'SEINFRA'),
('Secretaria Municipal de Educação', 'SEDUC'),
('Secretaria Municipal de Saúde', 'SESA');

-- 2. Licitações (RF06)
INSERT INTO licitacao (numero_licitacao, modalidade, data_abertura, situacao) VALUES
('CP-001/2026', 'Concorrência Pública', '2026-01-15', 'homologada'),
('PE-014/2026', 'Pregão Eletrônico', '2026-03-10', 'em julgamento'),
('TP-005/2026', 'Tomada de Preços', '2025-11-20', 'homologada');

-- 3. Empresas Contratadas (RF02)
INSERT INTO empresa (razao_social, cnpj, telefone, email) VALUES
('Construtora Sertão Forte Ltda', '12.345.678/0001-90', '(88) 99911-2233', 'contato@sertaoforte.com.br'),
('Engenharia Vale Central S.A.', '98.765.432/0001-10', '(88) 99822-3344', 'licitacoes@valecentral.com.br'),
('Pavimenta Ceará Obras Ltda', '45.678.912/0001-55', '(85) 3455-6677', 'engenharia@pavimentaceara.com.br');

-- 4. Obras Públicas (RF01, RF14)
-- Obs.: A Obra 3 entra inicialmente 'em andamento' para registrar suas fases concluídas e depois é encerrada.
INSERT INTO obra (titulo, local_execucao, data_inicio, data_prevista_conclusao, orcamento_previsto, situacao, id_secretaria, id_licitacao) VALUES
('Construção da Escola Municipal Tempo Integral', 'Bairro Campo Novo, Quixadá - CE', '2026-02-10', '2026-12-20', 2500000.00, 'em andamento', 2, 1),
('Reforma e Ampliação da UBS Central', 'Centro, Ocara - CE', '2026-06-01', '2027-02-28', 850000.00, 'planejada', 3, 2),
('Pavimentação Asfáltica da Avenida Principal', 'Distrito de Juatama, Quixadá - CE', '2025-12-05', '2026-08-30', 1400000.00, 'em andamento', 1, 3);

-- 5. Contratos de Execução (RF07, RN02)
INSERT INTO contrato (numero_contrato, data_assinatura, prazo_vigencia_dias, valor_contratado, id_obra, id_empresa) VALUES
('CTR-010/2026', '2026-02-05', 320, 2420000.00, 1, 1),
('CTR-022/2025', '2025-12-01', 270, 1380000.00, 3, 3);

-- 6. Fases e Medições (RF03, RN01, RN03)
INSERT INTO fase_medicao (nome_fase, data_medicao, percentual_conclusao, peso_fase, observacoes, id_obra) VALUES
('Terraplanagem e Fundação', '2026-04-15', 100.00, 35.00, 'Fundação concluída dentro do cronograma.', 1),
('Alvenaria e Cobertura', '2026-08-20', 70.00, 65.00, 'Estrutura metálica do telhado em montagem.', 1),
('Drenagem e Base Asfáltica', '2026-05-10', 100.00, 50.00, 'Etapa aprovada pela fiscalização.', 3),
('Pavimentação e Sinalização Viária', '2026-08-25', 100.00, 50.00, 'Obra entregue e sinalizada.', 3);

-- Encerrando a Obra 3 após conclusão de todas as suas fases (RN07)
UPDATE obra SET situacao = 'concluída' WHERE id_obra = 3;

-- 7. Aditivos Financeiros (RF04, RN04 - apenas na Obra 1 que está 'em andamento')
INSERT INTO aditivo_financeiro (valor_aditivo, data_aditivo, justificativa, id_obra) VALUES
(175000.00, '2026-07-12', 'Reforço estrutural devido à sondagem complementar do solo.', 1);

-- 8. Atualizações de Execução e Histórico (RF08, RF12, RF13, RF14, RN10)
INSERT INTO atualizacao_execucao (data_referencia, tipo_registro, situacao_registrada, nova_data_prevista, descricao, responsavel_registro, id_obra) VALUES
('2026-02-10', 'mudanca_situacao', 'em andamento', NULL, 'Ordem de serviço emitida e início do canteiro de obras.', 'Eng. Marcos Aurélio (SEDUC)', 1),
('2026-07-15', 'alteracao_prazo', NULL, '2026-12-20', 'Ajuste de 20 dias no cronograma após aditivo de fundação.', 'Eng. Marcos Aurélio (SEDUC)', 1),
('2026-08-25', 'mudanca_situacao', 'concluída', NULL, 'Termo de recebimento definitivo emitido.', 'Eng. Carla Mendes (SEINFRA)', 3);

-- 9. Documentos e Evidências (RF10)
INSERT INTO documento_evidencia (descricao, data_documento, localizacao_arquivo, id_obra, id_fase) VALUES
('Projeto Arquitetônico Executivo (PDF)', '2026-02-01', 'https://transparencia.gov.br/docs/obra1_projeto.pdf', 1, NULL),
('Relatório Fotográfico - 1ª Medição Fundação', '2026-04-16', 'https://transparencia.gov.br/docs/obra1_medicao1.pdf', 1, 1),
('Termo de Entrega Definitiva da Pavimentação', '2026-08-26', 'https://transparencia.gov.br/docs/obra3_entrega.pdf', 3, 4);

-- 10. Apontamentos de Cidadãos (RF05, RN09)
INSERT INTO apontamento_cidadao (descricao, data_registro, cpf_cidadao, id_obra) VALUES
('Placa de identificação da obra instalada corretamente na entrada do terreno.', '2026-03-02', '123.456.789-00', 1),
('Excelente qualidade do asfalto e das faixas de pedestres após a conclusão.', '2026-09-01', NULL, 3);
