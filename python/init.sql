-- ============================================================================
-- UNIVERSIDADE FEDERAL DO CEARÁ (UFC) - CAMPUS QUIXADÁ
-- DISCIPLINA: Fundamentos de Bancos de Dados (Etapa 2 - Projeto e Implementação)
-- PROJETO: Sistema de Acompanhamento de Obras Públicas (Equipe T01)
-- SCRIPT 01: Criação das estruturas do banco de dados, restrições e triggers
-- ============================================================================

DROP TABLE IF EXISTS apontamento_cidadao CASCADE;
DROP TABLE IF EXISTS documento_evidencia CASCADE;
DROP TABLE IF EXISTS atualizacao_execucao CASCADE;
DROP TABLE IF EXISTS aditivo_financeiro CASCADE;
DROP TABLE IF EXISTS fase_medicao CASCADE;
DROP TABLE IF EXISTS contrato CASCADE;
DROP TABLE IF EXISTS obra CASCADE;
DROP TABLE IF EXISTS empresa CASCADE;
DROP TABLE IF EXISTS licitacao CASCADE;
DROP TABLE IF EXISTS secretaria CASCADE;

-- 1. SECRETARIA (RF11)
CREATE TABLE secretaria (
    id_secretaria SERIAL PRIMARY KEY,
    nome_oficial VARCHAR(150) NOT NULL UNIQUE,
    sigla VARCHAR(20)
);

-- 2. LICITACAO (RF06, RN05)
CREATE TABLE licitacao (
    id_licitacao SERIAL PRIMARY KEY,
    numero_licitacao VARCHAR(50) NOT NULL UNIQUE,
    modalidade VARCHAR(60) NOT NULL,
    data_abertura DATE NOT NULL,
    situacao VARCHAR(40) NOT NULL CHECK (
        situacao IN ('aberta', 'em julgamento', 'homologada', 'deserta', 'cancelada')
    )
);

-- 3. EMPRESA (RF02, RN05)
CREATE TABLE empresa (
    id_empresa SERIAL PRIMARY KEY,
    razao_social VARCHAR(150) NOT NULL,
    cnpj VARCHAR(18) NOT NULL UNIQUE CHECK (
        char_length(regexp_replace(cnpj, '\D', '', 'g')) = 14
    ),
    telefone VARCHAR(20),
    email VARCHAR(120)
);

-- 4. OBRA (RF01, RF08, RF09, RF14, RN06, RN07, RN08)
CREATE TABLE obra (
    id_obra SERIAL PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    local_execucao VARCHAR(255) NOT NULL,
    data_inicio DATE NOT NULL,
    data_prevista_conclusao DATE NOT NULL,
    orcamento_previsto NUMERIC(14, 2) NOT NULL CHECK (orcamento_previsto > 0),
    situacao VARCHAR(30) NOT NULL DEFAULT 'planejada' CHECK (
        situacao IN ('planejada', 'em andamento', 'suspensa', 'concluída', 'cancelada')
    ),
    id_secretaria INT NOT NULL REFERENCES secretaria(id_secretaria) ON DELETE RESTRICT,
    id_licitacao INT NULL REFERENCES licitacao(id_licitacao) ON DELETE SET NULL,
    CHECK (data_prevista_conclusao >= data_inicio)
);

-- 5. CONTRATO (RF07, RF15, RN02, RN05, RN06)
CREATE TABLE contrato (
    id_contrato SERIAL PRIMARY KEY,
    numero_contrato VARCHAR(50) NOT NULL UNIQUE,
    data_assinatura DATE NOT NULL,
    prazo_vigencia_dias INT NOT NULL CHECK (prazo_vigencia_dias > 0),
    valor_contratado NUMERIC(14, 2) NOT NULL CHECK (valor_contratado > 0),
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE,
    id_empresa INT NOT NULL REFERENCES empresa(id_empresa) ON DELETE RESTRICT
);

-- 6. FASE_MEDICAO (RF03, RN01, RN03, RN06, RN07)
CREATE TABLE fase_medicao (
    id_fase SERIAL PRIMARY KEY,
    nome_fase VARCHAR(120) NOT NULL,
    data_medicao DATE NOT NULL,
    percentual_conclusao NUMERIC(5, 2) NOT NULL CHECK (
        percentual_conclusao >= 0 AND percentual_conclusao <= 100
    ),
    peso_fase NUMERIC(5, 2) NOT NULL DEFAULT 100.00 CHECK (
        peso_fase > 0 AND peso_fase <= 100
    ),
    observacoes TEXT,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- 7. ADITIVO_FINANCEIRO (RF04, RF15, RN04, RN06)
CREATE TABLE aditivo_financeiro (
    id_aditivo SERIAL PRIMARY KEY,
    valor_aditivo NUMERIC(14, 2) NOT NULL CHECK (valor_aditivo > 0),
    data_aditivo DATE NOT NULL DEFAULT CURRENT_DATE,
    justificativa TEXT NOT NULL,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- 8. ATUALIZACAO_EXECUCAO (RF08, RF12, RF13, RF14, RN10)
CREATE TABLE atualizacao_execucao (
    id_atualizacao SERIAL PRIMARY KEY,
    data_referencia DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo_registro VARCHAR(30) NOT NULL CHECK (
        tipo_registro IN ('andamento', 'mudanca_situacao', 'alteracao_prazo')
    ),
    situacao_registrada VARCHAR(30) NULL CHECK (
        situacao_registrada IN ('planejada', 'em andamento', 'suspensa', 'concluída', 'cancelada')
    ),
    nova_data_prevista DATE NULL,
    descricao TEXT NOT NULL,
    responsavel_registro VARCHAR(120) NOT NULL,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- 9. DOCUMENTO_EVIDENCIA (RF10, RN06)
CREATE TABLE documento_evidencia (
    id_documento SERIAL PRIMARY KEY,
    descricao VARCHAR(255) NOT NULL,
    data_documento DATE NOT NULL DEFAULT CURRENT_DATE,
    localizacao_arquivo VARCHAR(500) NOT NULL,
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE,
    id_fase INT NULL REFERENCES fase_medicao(id_fase) ON DELETE SET NULL
);

-- 10. APONTAMENTO_CIDADAO (RF05, RN06, RN09)
CREATE TABLE apontamento_cidadao (
    id_apontamento SERIAL PRIMARY KEY,
    descricao TEXT NOT NULL,
    data_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    cpf_cidadao VARCHAR(14) NULL CHECK (
        cpf_cidadao IS NULL OR char_length(regexp_replace(cpf_cidadao, '\D', '', 'g')) = 11
    ),
    id_obra INT NOT NULL REFERENCES obra(id_obra) ON DELETE CASCADE
);

-- ============================================================================
-- TRIGGERS DE REGRAS DE NEGÓCIO (RN04 e RN07)
-- ============================================================================

-- RN04: Aditivo financeiro só pode ser registrado para obra 'em andamento'
CREATE OR REPLACE FUNCTION fn_validar_aditivo_obra()
RETURNS TRIGGER AS $$
DECLARE
    v_situacao VARCHAR(30);
BEGIN
    SELECT situacao INTO v_situacao FROM obra WHERE id_obra = NEW.id_obra;
    IF v_situacao <> 'em andamento' THEN
        RAISE EXCEPTION 'RN04: Não é permitido registrar aditivo para obra com situação "%". A obra deve estar "em andamento".', v_situacao;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_aditivo_obra
BEFORE INSERT ON aditivo_financeiro
FOR EACH ROW EXECUTE FUNCTION fn_validar_aditivo_obra();

-- RN07: Obra 'concluída' não deve receber novas medições de execução
CREATE OR REPLACE FUNCTION fn_validar_medicao_obra_concluida()
RETURNS TRIGGER AS $$
DECLARE
    v_situacao VARCHAR(30);
BEGIN
    SELECT situacao INTO v_situacao FROM obra WHERE id_obra = NEW.id_obra;
    IF v_situacao = 'concluída' THEN
        RAISE EXCEPTION 'RN07: Obra já concluída não pode receber novas medições sem reabertura formal.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_medicao_obra_concluida
BEFORE INSERT ON fase_medicao
FOR EACH ROW EXECUTE FUNCTION fn_validar_medicao_obra_concluida();
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
